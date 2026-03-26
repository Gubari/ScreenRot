extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 200.0
var damage: int = 1

func _ready() -> void:
	add_to_group("enemy_bullets")

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	rotation = direction.angle()
	var viewport_rect := get_viewport_rect()
	if not viewport_rect.has_point(global_position):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player") and body.has_method("take_damage"):
		body.take_damage(damage)
		_explode()

func _explode() -> void:
	speed = 0.0
	set_deferred("monitoring", false)
	var spr := $Sprite as AnimatedSprite2D
	if spr and spr.sprite_frames.has_animation("explode"):
		spr.play("explode")
		await spr.animation_finished
	queue_free()
