extends CharacterBody2D

signal enemy_killed(pos: Vector2, enemy_type: String)
signal hatch_requested(pos: Vector2)

@export var hatch_time: float = 3.0
@export var hp: int = 2

var _alive: bool = true
var _timer: float = 0.0

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var body_shape: CollisionShape2D = $CollisionShape2D
@onready var hitbox_shape: CollisionShape2D = $Hitbox/HitboxShape

func _ready() -> void:
	add_to_group("enemies")
	_timer = hatch_time
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("spawn_idle"):
		sprite.play("spawn_idle")

func _physics_process(delta: float) -> void:
	if not _alive:
		return
	_timer -= delta
	if _timer <= 0.0:
		_hatch()

func take_damage(amount: int) -> void:
	if not _alive:
		return
	hp -= amount
	if hp <= 0:
		_break_egg()

func _hatch() -> void:
	if not _alive:
		return
	_alive = false
	_disable_collisions()
	# Auto hatch should not count as a kill/debris event.
	if sprite:
		sprite.visible = false
	hatch_requested.emit(global_position)
	queue_free()

func _break_egg() -> void:
	if not _alive:
		return
	# Stop hatch timer so _hatch() can never run after this (same frame / later).
	set_physics_process(false)
	_alive = false
	_disable_collisions()
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("spawn_death"):
		sprite.play("spawn_death")
	# Screen debris + kill count; do NOT emit hatch_requested — fly never spawns.
	enemy_killed.emit(global_position, "toxic_fly_egg")

func _disable_collisions() -> void:
	if body_shape:
		body_shape.disabled = true
	if hitbox_shape:
		hitbox_shape.disabled = true

