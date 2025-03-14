extends CharacterBody2D

# Exports (these must come before regular variables)
@export var gravity = 200.0
@export var walk_speed = 200
@export var jump_speed = -300
@export var max_jumps = 2
@export var dash_speed = 500
@export var dash_duration = 0.2
@export var dash_cooldown = 0.5
@export var double_tap_threshold = 0.3
@export var crouch_speed = 100
@export var crouch_height = 60
@export var normal_height = 97.5
@export var attack_range = 70  # Range for detecting enemies to attack

# Public variables
var jumps = 0
var can_dash = true
var is_dashing = false
var dash_direction = Vector2.ZERO
var dash_timer = 0.0
var dash_cooldown_timer = 0.0
var last_press_time = {"ui_left": 0, "ui_right": 0}
var is_crouching = false
var can_stand = true  # To check if the player can stand up
var facing_right = true
var is_walking = false
var attack_cooldown = 0.0
var attack_cooldown_time = 0.5  # Time between attacks
var last_attack_time = 0
var attack_double_press_threshold = 0.5

# OnReady variables (these come after regular variables)
@onready var collision_shape = $CollisionShape2D
@onready var animated_sprite = $AnimatedSprite2D
@onready var jump_sound = $JumpSound


# Called when the node enters the scene tree for the first time.
func _ready():
	# Set the initial animation
	animated_sprite.play("idle")

	# Make sure the jump sound is set up properly
	if jump_sound == null:
		# If you haven't added the node yet, we'll create one dynamically
		jump_sound = AudioStreamPlayer.new()
		add_child(jump_sound)
		
		# Load the jump sound
		var sound = load("res://assets/sound/player_jump.mp3")
		if sound:
			jump_sound.stream = sound


func _physics_process(delta):
	if !can_dash:
		dash_cooldown_timer += delta
		if dash_cooldown_timer >= dash_cooldown:
			can_dash = true
			dash_cooldown_timer = 0.0
			
	# Decrease attack cooldown
	if attack_cooldown > 0:
		attack_cooldown -= delta

	# Processing Crouch
	process_crouch()

	velocity.y += delta * gravity

	if is_on_floor():
		jumps = 0

	if Input.is_action_just_pressed("ui_up") and jumps < max_jumps:
		velocity.y = jump_speed
		jumps += 1
		# Play jump sound
		if jump_sound and jump_sound.stream:
			jump_sound.play()

	# Check for attack input (S key)
	if Input.is_action_just_pressed("ui_down") and attack_cooldown <= 0 and !is_crouching:
		attack()

	if Input.is_action_just_pressed("ui_left"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if (
			current_time - last_press_time["ui_left"] < double_tap_threshold
			and can_dash
			and !is_dashing
		):
			start_dash(Vector2.LEFT)
		last_press_time["ui_left"] = current_time
	elif Input.is_action_just_pressed("ui_right"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if (
			current_time - last_press_time["ui_right"] < double_tap_threshold
			and can_dash
			and !is_dashing
		):
			start_dash(Vector2.RIGHT)
		last_press_time["ui_right"] = current_time

	# Handle dashing
	if is_dashing:
		dash_timer += delta
		velocity.x = dash_direction.x * dash_speed

		if dash_timer >= dash_duration:
			is_dashing = false
			dash_timer = 0.0
	else:
		velocity.y += delta * gravity

		if is_on_floor():
			jumps = 0

	if Input.is_action_just_pressed("ui_up") and jumps < max_jumps:
		velocity.y = jump_speed
		jumps += 1

	if !is_dashing:
		if Input.is_action_pressed("ui_left"):
			velocity.x = -walk_speed
			facing_right = false
			is_walking = true
		elif Input.is_action_pressed("ui_right"):
			velocity.x = walk_speed
			facing_right = true
			is_walking = true
		else:
			velocity.x = 0
			is_walking = false

	if is_crouching:
		velocity.x = 0
		if Input.is_action_pressed("ui_left"):
			velocity.x = -crouch_speed
			facing_right = false
		elif Input.is_action_pressed("ui_right"):
			velocity.x = crouch_speed
			facing_right = true

	# Update animation
	update_animation()

	# "move_and_slide" already takes delta time into account.
	move_and_slide()


func start_dash(direction):
	is_dashing = true
	can_dash = false
	dash_direction = direction
	dash_timer = 0.0
	dash_cooldown_timer = 0.0


func process_crouch():
	if is_on_floor():
		if Input.is_action_pressed("ui_down"):
			if !is_crouching:
				# Start crouching
				is_crouching = true

				# Adjust the collision shape
				collision_shape.shape.size.y = crouch_height
				collision_shape.position.y = (normal_height - crouch_height) / 2
				
				# Update animation
				animated_sprite.play("crouch")

		elif is_crouching and can_stand:
			# Stand up
			is_crouching = false

			# Adjust the collision shape
			collision_shape.shape.size.y = normal_height
			collision_shape.position.y = 0
			
			# Animation will be updated in update_animation()

	# Check if the player can stand up
	if is_crouching:
		var space_state = get_world_2d().direct_space_state
		var query = PhysicsRayQueryParameters2D.create(
			global_position,
			global_position + Vector2(0, -(normal_height - crouch_height)),
			collision_mask,
			[get_rid()]  # Exclude self
		)
		var result = space_state.intersect_ray(query)
		can_stand = result.is_empty()


func update_animation():
	# Update sprite direction
	animated_sprite.flip_h = !facing_right

	# Handle animation based on the state
	if is_crouching:
		# Already handled in process_crouch()
		pass
	elif !is_on_floor():
		# For jumping and falling, we'll use idle animation for now
		# Note: You might want to add jump and fall animations to your spritesheet
		animated_sprite.play("idle")
	elif is_walking:
		# Walking animation
		animated_sprite.play("walk right")
	else:
		# Idle
		animated_sprite.play("idle")


func attack():
	print("Player attacked")
	
	# Check for double press
	var current_time = Time.get_ticks_msec() / 1000.0
	var is_double_press = current_time - last_attack_time < attack_double_press_threshold
	last_attack_time = current_time
	
	attack_cooldown = attack_cooldown_time
	
	# Flash briefly to indicate attack
	modulate = Color(1.2, 1.2, 1.2)  # Slightly brighter
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color(1, 1, 1), 0.2)
	
	# Get attack direction based on facing
	var attack_direction = 1 if facing_right else -1
	
	# Find enemies in attack range
	var space_state = get_world_2d().direct_space_state
	
	# Define the attack area as a rectangle in front of the player
	var query_shape = RectangleShape2D.new()
	query_shape.size = Vector2(attack_range, collision_shape.shape.size.y)
	
	# Position the query shape in front of the player
	var query = PhysicsShapeQueryParameters2D.new()
	query.shape = query_shape
	query.transform = Transform2D(0, global_position + Vector2(attack_direction * attack_range/2, 0))
	query.collision_mask = 2  # Assuming enemies are on layer 2, adjust as needed
	
	# Perform the query
	var results = space_state.intersect_shape(query)
	
	# Process each hit body
	for result in results:
		var body = result.collider
		
		# Check if this is an enemy (has 'take_damage' method)
		if body.has_method("take_damage") or body.has_method("die"):
			print("Hit enemy: ", body.name)
			
			# If it's a double press, make the enemy disappear
			if is_double_press:
				print("Double press detected! Enemy will be removed.")
				body.queue_free()  # Most reliable way to remove a node
			else:
				# Single press - just do damage if the method exists
				if body.has_method("take_damage"):
					body.take_damage(10)  # Apply some damage
