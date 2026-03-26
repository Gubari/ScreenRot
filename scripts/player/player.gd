extends CharacterBody2D

signal player_died(score: int, credits: int)
signal player_damaged(current_hp: int)
signal defrag_activated()
signal score_changed(score: int, multiplier: int)
signal wave_completed(wave_number: int)

# Movement
@export var move_speed: float = 250.0

# Shooting
@export var fire_rate: float = 0.15
@export var bullet_speed: float = 600.0
@export var bullet_damage: int = 1
# In sprite pixels (96×96 frame); scaled by Sprite2D.scale in handle_rotation.
@export var muzzle_offset: Vector2 = Vector2(24, 22)

# HP
@export var max_hp: int = 5
var current_hp: int

# Score
var score: int = 0
var multiplier: int = 1

# Defrag
@export var defrag_cooldown: float = 12.0
var defrag_timer: float = 0.0
var can_defrag: bool = true

# Dash
@export var dash_speed: float = 600.0
@export var dash_duration: float = 0.15
@export var dash_cooldown: float = 3.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var can_dash: bool = true
var is_dashing: bool = false
var dash_direction: Vector2 = Vector2.ZERO

# Shooting state
var fire_timer: float = 0.0
var can_shoot: bool = true

# Map bounds (set by game_manager after map generation)
var map_rect: Rect2 = Rect2()

# Invincibility after damage
var invincible: bool = false
var invincible_timer: float = 0.0
@export var invincible_duration: float = 1.0

# References
@onready var sprite: AnimatedSprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var muzzle: Marker2D = $Muzzle

var bullet_scene: PackedScene

func _ready() -> void:
	current_hp = max_hp
	bullet_scene = preload("res://scenes/player/bullet.tscn")
	add_to_group("player")
	CursorManager.set_crosshair()

func _physics_process(delta: float) -> void:
	handle_dash(delta)
	if not is_dashing:
		handle_movement()
	handle_rotation()
	handle_shooting(delta)
	handle_defrag(delta)
	handle_invincibility(delta)
	move_and_slide()
	clamp_to_arena()

func handle_movement() -> void:
	var input_dir := Vector2.ZERO
	input_dir.x = Input.get_axis("move_left", "move_right")
	input_dir.y = Input.get_axis("move_up", "move_down")
	input_dir = input_dir.normalized()
	velocity = input_dir * move_speed
	# Animation
	if input_dir != Vector2.ZERO:
		sprite.play("walk")
	else:
		sprite.play("idle")

func handle_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	# Flip sprite based on mouse direction
	sprite.flip_h = mouse_pos.x < global_position.x
	var aim_angle := (mouse_pos - global_position).angle()
	# Gun stays on the sprite; do not rotate offset with aim or the spawn slides toward the head when aiming up.
	var local_off := Vector2(
		muzzle_offset.x * (-1.0 if sprite.flip_h else 1.0),
		muzzle_offset.y
	) * sprite.scale.x
	muzzle.position = local_off
	muzzle.rotation = aim_angle

func handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if fire_timer < 0:
		fire_timer = 0
	if Input.is_action_pressed("shoot") and fire_timer <= 0 and can_shoot:
		shoot()
		fire_timer = fire_rate

func shoot() -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = muzzle.global_position
	# Aim from muzzle toward cursor; center→mouse would miss the crosshair when spawn is offset.
	var aim_dir: Vector2 = (get_global_mouse_position() - bullet.global_position).normalized()
	bullet.rotation = aim_dir.angle()
	bullet.direction = aim_dir
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	get_tree().current_scene.add_child(bullet)
	AudioManager.play_sfx("shoot")

func handle_defrag(delta: float) -> void:
	if not can_defrag:
		defrag_timer -= delta
		if defrag_timer <= 0:
			can_defrag = true
			defrag_timer = 0
	if Input.is_action_just_pressed("defrag") and can_defrag:
		activate_defrag()

func activate_defrag() -> void:
	can_defrag = false
	defrag_timer = defrag_cooldown
	multiplier = 1
	score_changed.emit(score, multiplier)
	defrag_activated.emit()
	AudioManager.play_sfx("defrag")

func handle_dash(delta: float) -> void:
	# Cooldown
	if not can_dash and not is_dashing:
		dash_cooldown_timer -= delta
		if dash_cooldown_timer <= 0:
			can_dash = true

	# During dash
	if is_dashing:
		dash_timer -= delta
		velocity = dash_direction * dash_speed
		if dash_timer <= 0:
			is_dashing = false
			invincible = false

	# Start dash
	if Input.is_action_just_pressed("dash") and can_dash and not is_dashing:
		var input_dir := Vector2.ZERO
		input_dir.x = Input.get_axis("move_left", "move_right")
		input_dir.y = Input.get_axis("move_up", "move_down")
		if input_dir == Vector2.ZERO:
			# Dash toward mouse if not moving
			input_dir = (get_global_mouse_position() - global_position).normalized()
		else:
			input_dir = input_dir.normalized()
		dash_direction = input_dir
		is_dashing = true
		invincible = true
		dash_timer = dash_duration
		can_dash = false
		dash_cooldown_timer = dash_cooldown
		# Dash trail effect
		_spawn_dash_ghost()
		AudioManager.play_sfx("dash")

func _spawn_dash_ghost() -> void:
	var ghost = Sprite2D.new()
	ghost.texture = sprite.sprite_frames.get_frame_texture(sprite.animation, sprite.frame)
	ghost.scale = sprite.scale
	ghost.flip_h = sprite.flip_h
	ghost.modulate = Color(0, 1, 1, 0.4)
	ghost.global_position = global_position
	get_tree().current_scene.add_child(ghost)
	var tween = ghost.create_tween()
	tween.tween_property(ghost, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ghost.queue_free)

func handle_invincibility(delta: float) -> void:
	if invincible and not is_dashing:
		invincible_timer -= delta
		sprite.visible = fmod(invincible_timer, 0.2) > 0.1
		if invincible_timer <= 0:
			invincible = false
			sprite.visible = true

func take_damage(amount: int = 1) -> void:
	if invincible:
		return
	current_hp -= amount
	current_hp = max(current_hp, 0)
	player_damaged.emit(current_hp)
	if current_hp <= 0:
		die()
		AudioManager.play_sfx("player_death")
	else:
		AudioManager.play_sfx("player_damage")
		invincible = true
		invincible_timer = invincible_duration

func die() -> void:
	player_died.emit(score, int(score / 100))
	set_physics_process(false)
	visible = false

func add_score(points: int) -> void:
	score += points * multiplier
	score_changed.emit(score, multiplier)

func set_multiplier(new_multiplier: int) -> void:
	multiplier = new_multiplier
	score_changed.emit(score, multiplier)

func clamp_to_arena() -> void:
	if map_rect.size == Vector2.ZERO:
		var viewport_rect := get_viewport_rect()
		global_position.x = clamp(global_position.x, 16, viewport_rect.size.x - 16)
		global_position.y = clamp(global_position.y, 16, viewport_rect.size.y - 16)
		return
	var margin := 16.0
	global_position.x = clamp(global_position.x, map_rect.position.x + margin, map_rect.end.x - margin)
	global_position.y = clamp(global_position.y, map_rect.position.y + margin, map_rect.end.y - margin)

func setup_camera_limits(rect: Rect2) -> void:
	var cam := $Camera2D as Camera2D
	if cam:
		cam.limit_left = int(rect.position.x)
		cam.limit_top = int(rect.position.y)
		cam.limit_right = int(rect.end.x)
		cam.limit_bottom = int(rect.end.y)

func get_defrag_percent() -> float:
	if can_defrag:
		return 1.0
	return 1.0 - (defrag_timer / defrag_cooldown)

func get_dash_percent() -> float:
	if can_dash:
		return 1.0
	return 1.0 - (dash_cooldown_timer / dash_cooldown)
