extends EnemyBase

var zig_zag_timer: float = 0.0
var zig_zag_dir: float = 1.0
@export var zig_zag_interval: float = 0.8

func _ready() -> void:
	enemy_type = "static_walker"
	super._ready()

func do_movement(delta: float) -> void:
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		_update_nav_target()

	zig_zag_timer += delta
	if zig_zag_timer >= zig_zag_interval:
		zig_zag_timer = 0.0
		zig_zag_dir *= -1.0

	var to_player := get_nav_direction()
	var perpendicular := Vector2(-to_player.y, to_player.x)
	var dir := (to_player + perpendicular * zig_zag_dir * 0.6).normalized()
	var desired_velocity := MovementFormula.velocity(dir, move_speed)
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = velocity.x < 0.0
