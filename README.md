# Nama: Muhammad Nanda Pratama
# NPM: 2206081654

## Implementasi Fitur Lanjutan Platformer Game

### 1. Implementasi Double Jump
Kita dapat melakukannya dengan cara:
   - Menambahkan variabel `max_jumps` untuk menentukan jumlah maksimum lompatan yang diperbolehkan.
   - Menambahkan variabel `jumps_made` untuk melacak berapa kali pemain sudah melompat.

Kemudian, kita lakukan modifikasi pada Player.gd menjadi seperti ini:
```javascript
extends CharacterBody2D

@export var gravity = 200.0
@export var walk_speed = 200
@export var jump_speed = -300
@export var max_jumps = 2
var jumps = 0


# Called when the node enters the scene tree for the first time.
func _ready():
	pass # Replace with function body.


# Called every frame. 'delta' is the elapsed time since the previous frame.
func _process(delta):
	pass
	

func _physics_process(delta):
	velocity.y += delta * gravity
	
	if is_on_floor():
		jumps = 0

	if Input.is_action_just_pressed("ui_up") and jumps < max_jumps:
		velocity.y = jump_speed
		jumps += 1
	
	if Input.is_action_pressed("ui_left"):
		velocity.x = -walk_speed
	elif Input.is_action_pressed("ui_right"):
		velocity.x =  walk_speed
	else:
		velocity.x = 0

	# "move_and_slide" already takes delta time into account.
	move_and_slide()
```

### 2. Implementasi Dashing
Kita dapat melakukannya dengan cara modifikasi pada Player.gd:

**- Menambahkan Variabel untuk Dashing**:
   ```javascript
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
   ```

**- Mendeteksi Double Tap**:
Kode ini memeriksa apakah pemain menekan tombol yang sama dua kali dalam interval waktu yang singkat (kurang dari double_tap_threshold). Jika ya, dash akan diaktifkan ke arah tersebut. Kita menggunakan is_action_just_pressed() yang hanya terpicu saat awal tombol ditekan (jadi hold press tidak termasuk).
```javascript
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
```

**- Handle dash**:
Selama dashing aktif, karakter bergerak dengan kecepatan dash ke arah yang ditentukan. Dash berakhir setelah durasi yang ditentukan.
```javascript
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
```

**- Handle dash cooldown**:
Setelah dash selesai, pemain harus menunggu selama periode cooldown sebelum bisa melakukan dash lagi.
```javascript
	if !can_dash:
		dash_cooldown_timer += delta
		if dash_cooldown_timer >= dash_cooldown:
			can_dash = true
			dash_cooldown_timer = 0.0
```

**- Fungsi start_dash untuk memulai dash**:
```javascript
func start_dash(direction):
	is_dashing = true
	can_dash = false
	dash_direction = direction
	dash_timer = 0.0
	dash_cooldown_timer = 0.0
```


### 3. Implementasi Crouching

**- Menambahkan Variabel untuk Crouching**:
  ```javascript
    # Crouching
    @export var crouch_speed = 100
    @export var crouch_height = 60
    @export var normal_height = 97.5
    var is_crouching = false
    var can_stand = true # To check if the player can stand up

    @onready var collision_shape = $CollisionShape2D
    @onready var sprite = $Sprite2D
    # Store the original sprite textures
    var normal_texture
    var crouch_texture
   ```

**- Load texture**:
```javascript
func _ready():
	# Store the original sprite textures
	normal_texture = sprite.texture
	crouch_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_duck.png")
``` 

**- Modifikasi gerakan**:
```javascript
	if is_crouching:
		velocity.x = 0
		if Input.is_action_pressed("ui_left"):
			velocity.x = -crouch_speed
		elif Input.is_action_pressed("ui_right"):
			velocity.x = crouch_speed
```

### 4. Implementasi Tambahan

**- Menambahkan Variabel untuk Dashing**:
```javascript
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
```


**- Sprite untuk animasi gerakan**:
Disini kita akan implementasi animasi secara manual, kita belum menggunakan cara otomatis yang ada di Godot
```javascript
func _ready():
	# Store the original sprite textures
	normal_texture = sprite.texture
	crouch_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_duck.png")
	walk1_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_walk1.png")
	walk2_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_walk2.png")
	jump_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_jump.png")
	fall_texture = load("res://assets/kenney_platformercharacters/PNG/Player/Poses/player_fall.png")
```

**-Deteksi arah jalannya player**:
Referensi: https://forum.godotengine.org/t/flipping-sprite-around/40427
```javascript
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
```

**-Function update animation**:
```javascript
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
```


### 5. Perbaikan kode untuk CI/CD

Dalam proses CI/CD (Continuous Integration/Continuous Deployment), saya menghadapi beberapa error terkait linting dari GDScript. Error yang muncul adalah "Definition out of order" yang berarti deklarasi variabel dan fungsi dalam script tidak mengikuti urutan yang ditentukan dalam konfigurasi linting.
Error disebabkan oleh urutan definisi yang tidak sesuai dengan aturan yang ditetapkan dalam file `gdlintrc`:


**- Solusi**:

Untuk menyelesaikan masalah tersebut, saya menyusun ulang kode dalam file `Player.gd` dengan urutan sebagai berikut:

**a.Pengelompokan @export variables:**
   ```javascript
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
   @export var animation_speed = 0.2
   ```
   
**b.Pengelompokan variable biasa:**
```javascript
    # Public variables
    var jumps = 0
    var can_dash = true
    var is_dashing = false
    var dash_direction = Vector2.ZERO
    var dash_timer = 0.0
    var dash_cooldown_timer = 0.0
    var last_press_time = {"ui_left": 0, "ui_right": 0}
    var is_crouching = false
    var can_stand = true
    var normal_texture
    var crouch_texture
    var walk1_texture
    var walk2_texture
    var jump_texture
    var fall_texture
    var facing_right = true
    var is_walking = false
    var animation_frame = 0
    var animation_timer = 0.0
```

**c.Pengelompokan variabel onready:**
```javascript
# OnReady variables
@onready var collision_shape = $CollisionShape2D
@onready var sprite = $Sprite2D
```

**d. Menghapus function func _process(delta):**

Setelah menerapkan perubahan tersebut, error CI/CD sudah berhasil diatasi. 
