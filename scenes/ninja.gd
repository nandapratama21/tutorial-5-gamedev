extends CharacterBody2D

# Exports
@export var gravity = 200.0
@export var walk_speed = 100
@export var detection_range = 300
@export var attack_range = 60
@export var patrol_points: Array[NodePath] = []
@export var health = 100
@export var damage = 10
@export var jump_height = -300  # How high the ninja jumps
@export var obstacle_check_distance = 20  # How far ahead to check for obstacles

# Variables
var current_patrol_index = 0
var patrol_targets = []
var player = null
var state = "idle"  # idle, patrol, chase, attack, jumping
var facing_right = true
var attack_cooldown = 0.0
var attack_cooldown_time = 1.0
var has_dealt_damage = false  # Track if we've dealt damage in the current attack
var jump_cooldown = 0.0
var jump_cooldown_time = 1.0  # Prevent constant jumping
var jump_target_direction = Vector2.ZERO  # Direction to move after jump

# OnReady variables
@onready var animated_sprite = $AnimatedSprite2D
@onready var collision_shape = $CollisionShape2D  # Added collision shape reference
@onready var attack_detector = $AttackDetector  # Reference to Area2D for collision detection
@onready var attack_sound = $AttackSound  # Add this for the attack sound


# Add this function to detect collisions with other bodies
func _on_attack_detector_body_entered(body):
	# Check if the colliding body is the player
	if body == player:
		print("Player collision detected")
		# Switch to attack state if not jumping
		if state != "jumping":
			state = "attack"


func _ready():
	# Initialize the animation
	animated_sprite.play("idle")

	# Set up patrol targets if specified
	for point_path in patrol_points:
		var point = get_node(point_path)
		if point:
			patrol_targets.append(point)

	# Connect animation signals
	animated_sprite.animation_finished.connect(_on_animation_finished)

	# Create and connect attack detector if it doesn't exist
	if not has_node("AttackDetector"):
		create_attack_detector()
	else:
		# Connect signals if it does exist
		attack_detector = $AttackDetector
		attack_detector.body_entered.connect(_on_attack_detector_body_entered)

	# Try to find the player in the scene
	player = get_tree().get_nodes_in_group("player")
	if player and player.size() > 0:
		player = player[0]
	else:
		player = get_tree().get_first_node_in_group("player")

	# If still no player found, try direct path
	if player == null:
		player = get_node_or_null("../Player")  # Assuming Player is a sibling node

	print("Player found: ", player != null)


func create_attack_sound():
	# Create an AudioStreamPlayer for the attack sound
	attack_sound = AudioStreamPlayer.new()
	attack_sound.name = "AttackSound"
	add_child(attack_sound)

	# Load the attack sound
	var sound = load("res://assets/sound/attack.mp3")
	if sound:
		attack_sound.stream = sound
	else:
		print("Failed to load attack sound")


func create_attack_detector():
	# Create an Area2D for attack detection
	attack_detector = Area2D.new()
	attack_detector.name = "AttackDetector"
	add_child(attack_detector)

	# Create a CollisionShape2D for the attack area
	var attack_shape = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = attack_range  # Use the attack_range for the radius
	attack_shape.shape = shape
	attack_detector.add_child(attack_shape)

	# Set collision mask to detect the player
	attack_detector.collision_mask = 1  # Adjust based on your player's collision layer
	attack_detector.monitoring = true

	# Connect signals
	attack_detector.body_entered.connect(_on_attack_detector_body_entered)


func _physics_process(delta):
	# Apply gravity
	if not is_on_floor():
		velocity.y += gravity * delta

	# Decrease attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta
		if attack_cooldown <= 0:
			has_dealt_damage = false  # Reset damage flag when cooldown ends

	# Decrease jump cooldown
	if jump_cooldown > 0:
		jump_cooldown -= delta

	# Override current state if player is in attack range
	if player and state != "attack" and state != "jumping" and is_player_in_range(attack_range):
		state = "attack"

	# State machine
	match state:
		"idle":
			velocity.x = 0
			process_idle_state()

		"patrol":
			process_patrol_state()

		"chase":
			process_chase_state()

		"attack":
			process_attack_state()

		"jumping":
			process_jumping_state()

	# Update animation
	update_animation()

	# Move the character
	move_and_slide()

	# Check if we've landed from a jump
	if state == "jumping" and is_on_floor():
		# Return to previous state (chase or patrol)
		if player and is_player_in_range(detection_range):
			state = "chase"
		else:
			state = "patrol"


func process_idle_state():
	# If we have patrol points, start patrolling
	if patrol_targets.size() > 0:
		state = "patrol"
		return

	# Check if player is in detection range
	if player and is_player_in_range(detection_range):
		state = "chase"


func process_patrol_state():
	# Check if player is in detection range
	if player and is_player_in_range(detection_range):
		state = "chase"
		return

	# Move towards the current patrol point
	if patrol_targets.size() > 0:
		var target = patrol_targets[current_patrol_index]
		var direction = global_position.direction_to(target.global_position)

		# Set facing direction
		if direction.x > 0:
			facing_right = true
		elif direction.x < 0:
			facing_right = false

		velocity.x = direction.x * walk_speed

		# Check for obstacles and jump if needed
		check_and_jump_obstacles(direction)

		# Check if we reached the target
		if global_position.distance_to(target.global_position) < 80:
			current_patrol_index = (current_patrol_index + 1) % patrol_targets.size()


func process_chase_state():
	# If player is null or out of range, go back to idle
	if not player or not is_player_in_range(detection_range * 1.5):
		state = "idle"
		return

	# If player is in attack range, switch to attack state
	if is_player_in_range(attack_range):
		state = "attack"
		return

	# Move towards player
	var direction = global_position.direction_to(player.global_position)

	# Set facing direction
	if direction.x > 0:
		facing_right = true
	elif direction.x < 0:
		facing_right = false

	velocity.x = direction.x * walk_speed

	# Check for obstacles and jump if needed
	check_and_jump_obstacles(direction)


func process_attack_state():
	# Stop moving when attacking
	velocity.x = 0

	# If player is out of range, chase again
	if not player or not is_player_in_range(attack_range * 1.2):
		state = "chase"
		return

	# Attack if cooldown is over
	if attack_cooldown <= 0:
		# Make sure we're facing the player before attacking
		if player:
			facing_right = player.global_position.x > global_position.x
		attack_player()

	# Always ensure we're facing the player when attacking
	if player:
		facing_right = player.global_position.x > global_position.x


func process_jumping_state():
	# While jumping, maintain horizontal movement in the target direction
	if jump_target_direction != Vector2.ZERO:
		velocity.x = jump_target_direction.x * walk_speed


func attack_player():
	# Stop any current animation and restart attack animation
	animated_sprite.stop()
	animated_sprite.play("attack")

	# Set attack cooldown
	attack_cooldown = attack_cooldown_time
	has_dealt_damage = false

	print("Ninja attacking player")


func check_and_jump_obstacles(direction):
	# Only check for obstacles if we're on the floor and the jump cooldown is over
	if is_on_floor() and jump_cooldown <= 0:
		# Cast a ray forward to detect obstacles
		var space_state = get_world_2d().direct_space_state
		var dir_x = 1 if facing_right else -1

		# Determine start position for the ray (accounting for the ninja's size)
		var ray_start = global_position + Vector2(dir_x * 10, -10)  # Start slightly ahead and above

		# First check: Are we near an obstacle?
		var query_near = PhysicsRayQueryParameters2D.create(
			ray_start,
			ray_start + Vector2(dir_x * obstacle_check_distance, 0),
			collision_mask,  # Use the same collision mask as the character
			[get_rid()]  # Exclude self
		)

		var result_near = space_state.intersect_ray(query_near)

		if result_near:
			# We found an obstacle directly in front of us
			print("Obstacle detected, attempting to jump")
			# Store the direction we want to go
			jump_target_direction = direction
			# Start jump
			jump()
			return

		# Only check for gaps when chasing, not during patrol
		if state == "chase":
			# Second check: Is there a gap in the floor ahead that we need to jump over?
			# First, check if there's ground beneath us
			var floor_check = PhysicsRayQueryParameters2D.create(
				global_position, global_position + Vector2(0, 30), collision_mask, [get_rid()]
			)

			var has_floor = space_state.intersect_ray(floor_check)

			if has_floor:
				# Now check if there's a gap ahead
				var gap_check_pos = global_position + Vector2(dir_x * obstacle_check_distance, 5)
				var query_gap = PhysicsRayQueryParameters2D.create(
					gap_check_pos, gap_check_pos + Vector2(0, 30), collision_mask, [get_rid()]
				)

				var result_gap = space_state.intersect_ray(query_gap)

				# Jump only if there's no floor ahead but we're currently on floor
				if not result_gap:
					print("Gap detected while chasing, attempting to jump")
					# Store the direction we want to go
					jump_target_direction = direction
					# Start jump
					jump()


func jump():
	if is_on_floor() and jump_cooldown <= 0:
		velocity.y = jump_height
		jump_cooldown = jump_cooldown_time
		animated_sprite.play("jump")
		print("Ninja jumped")
		# Change state to jumping to handle movement differently
		state = "jumping"


func _on_animation_finished():
	# Check if we just finished the attack animation
	if animated_sprite.animation == "attack" and not has_dealt_damage:
		# Deal damage to player if in range
		if player and is_player_in_range(attack_range):
			print("Attempting to damage player")
			# If player has a take_damage function, call it
			if player.has_method("take_damage"):
				player.take_damage(damage)
				print("Damage dealt to player: ", damage)
			else:
				print("Player doesn't have take_damage method")
			has_dealt_damage = true


func is_player_in_range(range_value):
	if not player:
		return false

	# Use simple distance check since PhysicsShapeQueryParameters2D might be causing issues
	var distance = global_position.distance_to(player.global_position)

	# Debug information
	if range_value == attack_range:
		print("Distance to player: ", distance, ", Attack range: ", range_value)
		if distance < 100:
			if attack_sound and attack_sound.stream:
				if not attack_sound.playing:
					attack_sound.play()

	return distance <= range_value


func update_animation():
	# Update sprite direction
	animated_sprite.flip_h = !facing_right

	# Current animation
	var current_anim = animated_sprite.animation

	# Play the appropriate animation based on state
	if state == "attack":
		# Always play attack animation in attack state
		if current_anim != "attack" or !animated_sprite.is_playing():
			animated_sprite.play("attack")
	elif !is_on_floor():
		# Play jump animation if we're in the air
		if current_anim != "jump":
			animated_sprite.play("jump")
	elif state == "idle":
		if current_anim != "idle":
			animated_sprite.play("idle")
	elif state == "patrol" or state == "chase":
		if velocity.x != 0 and current_anim != "run":
			animated_sprite.play("run")
		elif velocity.x == 0 and current_anim != "idle":
			animated_sprite.play("idle")


func take_damage(amount):
	health -= amount

	# Flash red to indicate damage
	modulate = Color(1, 0.3, 0.3, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1, 1), 0.3)

	if health <= 0:
		die()


func die():
	# Simple death for now - just remove from scene
	queue_free()
