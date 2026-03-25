extends EnemyBase

func _ready() -> void:
	max_hp = 1
	move_speed = 80.0
	score_value = 10
	enemy_type = "pixel_grunt"
	super._ready()

func do_movement(_delta: float) -> void:
	# Walks straight toward player
	var dir = (player.global_position - global_position).normalized()
	velocity = dir * move_speed
