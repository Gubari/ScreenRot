extends EnemyBase

var jitter_offset: Vector2 = Vector2.ZERO

func _ready() -> void:
	enemy_type = "bit_bug"
	super._ready()

func do_movement(delta: float) -> void:
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		_update_nav_target()

	jitter_offset = Vector2(randf_range(-0.3, 0.3), randf_range(-0.3, 0.3))
	var to_player := get_nav_direction()
	var dir := (to_player + jitter_offset).normalized()
	var desired_velocity := MovementFormula.velocity(dir, move_speed)
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity

	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and player and is_instance_valid(player):
		spr.flip_h = player.global_position.x < global_position.x
