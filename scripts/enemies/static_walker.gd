extends EnemyBase

var zig_zag_timer: float = 0.0
var zig_zag_dir: float = 1.0
@export var zig_zag_interval: float = 0.8

func _ready() -> void:
	max_hp = 2
	move_speed = 100.0
	score_value = 20
	enemy_type = "static_walker"
	super._ready()

func do_movement(delta: float) -> void:
	zig_zag_timer += delta
	if zig_zag_timer >= zig_zag_interval:
		zig_zag_timer = 0.0
		zig_zag_dir *= -1.0

	var to_player = (player.global_position - global_position).normalized()
	var perpendicular = Vector2(-to_player.y, to_player.x)
	var dir = (to_player + perpendicular * zig_zag_dir * 0.6).normalized()
	velocity = dir * move_speed
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = dir.x < 0.0
