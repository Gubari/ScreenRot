extends EnemyBase

var jitter_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	max_hp = 1
	move_speed = 150.0
	score_value = 10
	enemy_type = "bit_bug"
	super._ready()

func do_movement(_delta: float) -> void:
	# Fast, with slight random jitter
	jitter_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	var to_player = (player.global_position - global_position).normalized()
	var dir = (to_player + jitter_offset).normalized()
	velocity = dir * move_speed
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = dir.x < 0.0
