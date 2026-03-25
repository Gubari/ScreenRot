extends Area2D

var direction: Vector2 = Vector2.RIGHT
var speed: float = 600.0
var damage: int = 1

func _ready() -> void:
	add_to_group("player_bullets")

func _physics_process(delta: float) -> void:
	position += direction * speed * delta
	# Remove if off screen
	var viewport_rect := get_viewport_rect()
	if not viewport_rect.has_point(global_position):
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("enemies") and body.has_method("take_damage"):
		body.take_damage(damage)
		queue_free()
