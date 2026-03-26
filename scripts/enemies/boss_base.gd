extends EnemyBase
class_name BossBase

signal boss_defeated(boss_id: String, score: int)

@export var boss_id: String = "bloatware"
@export var bullet_damage: int = 1
@export var fire_rate: float = 2.0
@export var bullet_speed: float = 200.0

var fire_timer: float = 0.0
var is_dying: bool = false

var bullet_scene: PackedScene = preload("res://scenes/enemies/boss_bullet.tscn")

func _ready() -> void:
	enemy_type = "boss"
	super._ready()
	fire_timer = fire_rate

func _physics_process(delta: float) -> void:
	if is_dying:
		return
	super._physics_process(delta)
	if player and is_instance_valid(player) and player.visible:
		_handle_shooting(delta)
		_update_animation()

func do_movement(_delta: float) -> void:
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = dir.x < 0.0

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if fire_timer <= 0:
		fire_timer = fire_rate
		_shoot()

func _shoot() -> void:
	if not player or not is_instance_valid(player):
		return
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and spr.sprite_frames.has_animation("shoot"):
		spr.play("shoot")
		await spr.animation_finished
		if not is_instance_valid(self):
			return
		if spr.sprite_frames.has_animation("run"):
			spr.play("run")

	var dir = (player.global_position - global_position).normalized()
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	get_tree().current_scene.add_child(bullet)

func _update_animation() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if not spr:
		return
	if spr.animation == "shoot":
		return
	if velocity.length() > 5.0:
		if spr.sprite_frames.has_animation("run"):
			if spr.animation != "run":
				spr.play("run")
	else:
		if spr.sprite_frames.has_animation("idle"):
			if spr.animation != "idle":
				spr.play("idle")

func die() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and spr.sprite_frames.has_animation("death"):
		spr.play("death")
		await spr.animation_finished
	AudioManager.play_sfx("enemy_kill")
	enemy_killed.emit(global_position, enemy_type)
	boss_defeated.emit(boss_id, score_value)
	if player and player.has_method("add_score"):
		player.add_score(score_value)
	queue_free()
