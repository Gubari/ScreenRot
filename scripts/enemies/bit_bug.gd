extends EnemyBase

const PROJECTILE_SCENE = preload("res://scenes/enemies/projectile_bit_bug.tscn")

@export var shoot_range: float = 600.0
@export var keep_distance: float = 400.0
@export var shoot_cooldown: float = 2.0
@export var shoot_anim_duration: float = 0.4
@export var projectile_damage: int = 1
@export var projectile_speed: float = 320.0
@export var muzzle_offset: Vector2 = Vector2(15.0, -5.0)
## Izbegava brzo prebacivanje flip_h kad je igrač skoro ispod/iznad (isto X) — izgleda kao twitch pri horizontalnom hodu.
@export var flip_hysteresis_px: float = 24.0
## Kad igrač uđe preblizu, dron se odmakne dok ne bude ovaj mnogo veći od keep_distance — inače se šiba između „stani / povuci“ (pixel po pixel).
@export var retreat_clearance_px: float = 72.0
## Posle što igrač bude predaleko (van shoot_range), dron prvo dođe u opseg i ovoliko (s) čeka pre prvog pucnja.
@export var reengage_shoot_delay: float = 0.55

var _shoot_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _is_shooting_anim: bool = false
var _retreat_latched: bool = false
var _reengage_armed: bool = true
var _reengage_timer: float = 0.0

func _ready() -> void:
	enemy_type = "bit_bug"
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_shoot(delta)
	# _update_shoot menja _is_shooting_anim posle do_movement() u super-u — osveži animaciju u istom frejmu.
	_update_animation(get_node_or_null("Sprite") as AnimatedSprite2D)

func _update_shoot(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
		if _shoot_anim_timer <= 0.0:
			_is_shooting_anim = false

	_shoot_timer -= delta

	var dist := global_position.distance_to(player.global_position)
	var in_shoot_band := dist <= shoot_range and dist >= keep_distance

	if dist > shoot_range:
		_reengage_armed = false
		_reengage_timer = 0.0

	if in_shoot_band and not _reengage_armed:
		if _reengage_timer <= 0.0:
			_reengage_timer = maxf(reengage_shoot_delay, 0.0)
		_reengage_timer -= delta
		if _reengage_timer <= 0.0:
			_reengage_armed = true

	if in_shoot_band and _reengage_armed and _shoot_timer <= 0.0:
		_fire()
		_shoot_timer = shoot_cooldown
		_shoot_anim_timer = shoot_anim_duration
		_is_shooting_anim = true

func _fire() -> void:
	if not player or not is_instance_valid(player):
		return
	var proj = PROJECTILE_SCENE.instantiate()
	var dir := (player.global_position - global_position).normalized()
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	var flip := -1.0 if spr and spr.flip_h else 1.0
	var offset := Vector2(muzzle_offset.x * flip, muzzle_offset.y)
	proj.global_position = global_position + offset
	proj.direction = dir
	proj.rotation = dir.angle()
	proj.speed = projectile_speed
	proj.damage = projectile_damage
	get_tree().current_scene.call_deferred("add_child", proj)

func do_movement(delta: float) -> void:
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		_update_nav_target()

	if not player or not is_instance_valid(player):
		return

	var dist := global_position.distance_to(player.global_position)
	var raw_clear := keep_distance + maxf(retreat_clearance_px, 0.0)
	var clear_dist: float = minf(raw_clear, shoot_range - 4.0)
	if clear_dist <= keep_distance:
		clear_dist = keep_distance + (shoot_range - keep_distance) * 0.35

	var desired_velocity: Vector2
	if dist > shoot_range:
		_retreat_latched = false
		var toward := get_nav_direction()
		desired_velocity = MovementFormula.velocity(toward, move_speed)
	elif _retreat_latched:
		if dist >= clear_dist:
			_retreat_latched = false
			desired_velocity = Vector2.ZERO
		else:
			var away := (global_position - player.global_position).normalized()
			desired_velocity = MovementFormula.velocity(away, move_speed)
	else:
		if dist < keep_distance:
			_retreat_latched = true
			var away2 := (global_position - player.global_position).normalized()
			desired_velocity = MovementFormula.velocity(away2, move_speed)
		else:
			desired_velocity = Vector2.ZERO

	var holding_still := desired_velocity.length_squared() < 1.0
	if nav_agent:
		if holding_still:
			nav_agent.avoidance_enabled = false
			velocity = Vector2.ZERO
		else:
			nav_agent.avoidance_enabled = true
			nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity

	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and player and is_instance_valid(player):
		var dx := player.global_position.x - global_position.x
		var dead := maxf(flip_hysteresis_px, 0.0)
		if dx < -dead:
			spr.flip_h = true
		elif dx > dead:
			spr.flip_h = false

func _update_animation(spr: AnimatedSprite2D) -> void:
	if not spr or not spr.sprite_frames:
		return
	# Samo smrt: ne mešaj. Nemoj is_playing() — za loop=false (shoot) posle kraja je false i nikad ne bismo vratili walk/idle.
	if str(spr.animation) == "death":
		return

	if _is_shooting_anim and spr.sprite_frames.has_animation("shoot"):
		if str(spr.animation) != "shoot":
			spr.play("shoot")
		return

	if velocity.length() > 10.0:
		if str(spr.animation) != "walk":
			spr.play("walk")
	else:
		if str(spr.animation) != "idle":
			spr.play("idle")
