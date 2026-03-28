extends EnemyBase

const PROJECTILE_SCENE = preload("res://scenes/enemies/projectile_pixel_grunt.tscn")

@export var shoot_range: float = 400.0
@export var shoot_min_range: float = 200.0
@export var shoot_cooldown: float = 1.8
@export var shoot_anim_duration: float = 0.35
@export var projectile_damage: int = 1
@export var projectile_speed: float = 380.0
@export var muzzle_offset: Vector2 = Vector2(20.0, -5.0)

var _shoot_timer: float = 0.0
var _shoot_anim_timer: float = 0.0
var _is_shooting_anim: bool = false

func _ready() -> void:
	enemy_type = "pixel_grunt"
	super._ready()

func _physics_process(delta: float) -> void:
	super._physics_process(delta)
	_update_shoot(delta)
	_update_animation()

func _update_shoot(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return

	if _shoot_anim_timer > 0.0:
		_shoot_anim_timer -= delta
		if _shoot_anim_timer <= 0.0:
			_is_shooting_anim = false

	_shoot_timer -= delta

	var dist := global_position.distance_to(player.global_position)
	if dist <= shoot_range and dist >= shoot_min_range and _shoot_timer <= 0.0:
		_fire()
		_shoot_timer = shoot_cooldown
		_shoot_anim_timer = shoot_anim_duration
		_is_shooting_anim = true

func _fire() -> void:
	if not player or not is_instance_valid(player):
		return
	var proj = PROJECTILE_SCENE.instantiate()
	var dir := (player.global_position - global_position).normalized()
	var flip := -1.0 if get_node_or_null("Sprite") and (get_node_or_null("Sprite") as AnimatedSprite2D).flip_h else 1.0
	var offset := Vector2(muzzle_offset.x * flip, muzzle_offset.y)
	proj.global_position = global_position + offset
	proj.direction = dir
	proj.rotation = dir.angle()
	proj.speed = projectile_speed
	proj.damage = projectile_damage
	get_tree().current_scene.call_deferred("add_child", proj)

func _update_animation() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if not spr:
		return

	if not spr.is_playing() or spr.animation == "death":
		return

	if _is_shooting_anim:
		if spr.animation != "shoot":
			spr.play("shoot")
	else:
		if velocity.length() > 5.0:
			if spr.animation != "walk":
				spr.play("walk")
		else:
			if spr.animation != "idle":
				spr.play("idle")

func do_movement(delta: float) -> void:
	super.do_movement(delta)
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = velocity.x < 0.0
