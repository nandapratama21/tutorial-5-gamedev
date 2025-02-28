extends CharacterBody2D

# Jumping
@export var gravity = 200.0
@export var walk_speed = 200
@export var jump_speed = -300
@export var max_jumps = 2
var jumps = 0

# Dashing
@export var dash_speed = 500
@export var dash_duration = 0.2
@export var dash_cooldown = 0.5
var can_dash = true
var is_dashing = false
var dash_direction = Vector2.ZERO
var dash_timer = 0.0
var dash_cooldown_timer = 0.0

# Detecting double tap
var last_press_time = {"ui_left": 0, "ui_right": 0}
@export var double_tap_threshold = 0.3


# Crouching
@export var crouch_speed = 100
@export var crouch_height = 60
@export var normal_height = 97.5
var is_crouching = false
var can_stand = true # To check if the player can stand up

@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D
# Store the player sprite textures
var normal_texture
var crouch_texture
var walk1_texture
var walk2_texture
var jump_texture
var fall_texture


# Animation Sprite
var facing_right = true
var is_walking = false
var animation_frame = 0
var animation_timer = 0.0
@export var animation_speed = 0.2 # Time between walk animation frames




# Called when the node enters the scene tree for the first time.
func _ready():
	# Store the original sprite textures
	normal_texture = sprite.texture
	crouch_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_duck.png")
	walk1_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_walk1.png")
	walk2_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_walk2.png")
	jump_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_jump.png")
	fall_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_fall.png")



# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func _physics_process(delta):
	if !can_dash:
		dash_cooldown_timer += delta
		if dash_cooldown_timer >= dash_cooldown:
			can_dash = true
			dash_cooldown_timer = 0.0
	
	# Processing Crouch
	process_crouch()

	velocity.y += delta * gravity
	
	if is_on_floor():
		jumps = 0
			

	if Input.is_action_just_pressed("ui_up") and jumps < max_jumps:
		velocity.y = jump_speed
		jumps += 1

	
	if Input.is_action_just_pressed("ui_left"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_press_time["ui_left"] < double_tap_threshold and can_dash and !is_dashing:
			start_dash(Vector2.LEFT)
		last_press_time["ui_left"] = current_time
	elif Input.is_action_just_pressed("ui_right"):
		var current_time = Time.get_ticks_msec() / 1000.0
		if current_time - last_press_time["ui_right"] < double_tap_threshold and can_dash and !is_dashing:
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
	update_animation(delta)

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

				# Adjust the collision shape and sprite
				collision_shape.shape.size.y = crouch_height
				collision_shape.position.y = (normal_height - crouch_height) / 2

				# Change sprite texture
				sprite.texture = crouch_texture

		elif is_crouching and can_stand:
			# Stand up
			is_crouching = false

			# Adjust the collision shape and sprite
			collision_shape.shape.size.y = normal_height
			collision_shape.position.y = 0

			# Change sprite texture
			sprite.texture = normal_texture
	
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


func update_animation(delta):
	# Update sprite direction
	sprite.flip_h = !facing_right

	# Handle animation based on the state
	if !is_on_floor():
		# Jumping or falling
		if velocity.y < 0:
			sprite.texture = jump_texture
		else:
			sprite.texture = fall_texture
	elif is_crouching:
		# We already handle it in process_crouch()
		pass
	elif is_walking:
		# Walking
		animation_timer += delta
		if animation_timer >= animation_speed:
			animation_timer = 0
			animation_frame = 1 - animation_frame

			if animation_frame == 0:
				sprite.texture = walk1_texture
			else:
				sprite.texture = walk2_texture
	else:
		# Idle
		sprite.texture = normal_texture
