extends EnemyBase

func _ready() -> void:
	enemy_type = "toxic_fly"
	max_hp = 1
	move_speed = 155.0
	score_value = 14
	super._ready()

func do_movement(delta: float) -> void:
	# Fast flier with slight jitter, similar to bug but a bit more aggressive.
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		_update_nav_target()

	var jitter := Vector2(randf_range(-0.25, 0.25), randf_range(-0.25, 0.25))
	var to_player := get_nav_direction()
	var dir := (to_player + jitter).normalized()
	var desired_velocity := dir * move_speed
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity

	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and player and is_instance_valid(player):
		spr.flip_h = player.global_position.x < global_position.x
