extends Area2D
## Visual + movement stub for enemy shots (collision_layer = enemy_bullets).
## Scenes: projectile_pixel_grunt.tscn (projectiles sheet row 1), projectile_bit_bug.tscn (row 3).

@export var speed: float = 380.0
var direction: Vector2 = Vector2.RIGHT
@export var damage: int = 1

var _hit: bool = false

func _ready() -> void:
	add_to_group("enemy_bullets")

func _physics_process(delta: float) -> void:
	if _hit:
		return
	global_position += direction * speed * delta
	var cam := get_viewport().get_camera_2d()
	if cam and global_position.distance_to(cam.global_position) > 1600.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if _hit:
		return
	if body.is_in_group("player") and body.has_method("take_damage"):
		_hit = true
		body.take_damage(damage)
		queue_free()
