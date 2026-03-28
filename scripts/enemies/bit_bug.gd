extends EnemyBase

const PROJECTILE_SCENE = preload("res://scenes/enemies/projectile_bit_bug.tscn")

@export var shoot_range: float = 600.0
@export var keep_distance: float = 400.0
@export var shoot_cooldown: float = 2.0
@export var shoot_anim_duration: float = 0.4
@export var projectile_damage: int = 1
@export var projectile_speed: float = 320.0
@export var muzzle_offset: Vector2 = Vector2(15.0, -5.0)

var _shoot_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _is_shooting_anim: bool = false
var jitter_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	enemy_type = "bit_bug"
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_shoot(delta)

func _update_shoot(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
		if _shoot_anim_timer <= 0.0:
			_is_shooting_anim = false

	_shoot_timer -= delta

	var dist := global_position.distance_to(player.global_position)
	if dist <= shoot_range and dist >= keep_distance and _shoot_timer <= 0.0:
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
	jitter_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))

	var desired_velocity: Vector2
	if dist < keep_distance:
		# Preblizu — odmakni se od igrača
		var away := (global_position - player.global_position).normalized()
		var dir_away := (away + jitter_offset).normalized()
		desired_velocity = MovementFormula.velocity(dir_away, move_speed)
	elif dist > shoot_range:
		# Predaleko — priđi u range
		var toward := get_nav_direction()
		var dir_in := (toward + jitter_offset).normalized()
		desired_velocity = MovementFormula.velocity(dir_in, move_speed)
	else:
		# U sweet spotu — lagano kruži / drift
		desired_velocity = MovementFormula.velocity(jitter_offset, move_speed, 0.3)
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity

	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and player and is_instance_valid(player):
		spr.flip_h = player.global_position.x < global_position.x

	_update_animation(spr)

func _update_animation(spr: AnimatedSprite2D) -> void:
	if not spr:
		return
	if not spr.is_playing() or spr.animation == "death":
		return

	if _is_shooting_anim:
		if spr.animation != "shoot":
			spr.play("shoot")
	else:
		if velocity.length() > 10.0:
			if spr.animation != "walk":
				spr.play("walk")
		else:
			if spr.animation != "idle":
				spr.play("idle")
