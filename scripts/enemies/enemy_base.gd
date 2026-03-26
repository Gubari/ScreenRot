extends CharacterBody2D
class_name EnemyBase

signal enemy_killed(pos: Vector2, enemy_type: String)

@export var max_hp: int = 1
@export var move_speed: float = 80.0
@export var contact_damage: int = 1
@export var score_value: int = 10
@export var enemy_type: String = "grunt"

var current_hp: int
var player: Node2D = null
var touching_player: bool = false
var contact_tick_timer: float = 0.0
@export var contact_tick_rate: float = 0.5  # damage every 0.5s while touching

# Navigation
var nav_agent: NavigationAgent2D = null
var _nav_update_timer: float = 0.0
const NAV_UPDATE_INTERVAL: float = 0.15
var _stuck_timer: float = 0.0
var _last_pos: Vector2 = Vector2.ZERO

# Defrag drop
@export var defrag_drop_chance: float = 0.08  # 8% base chance

func _ready() -> void:
	current_hp = max_hp
	add_to_group("enemies")
	# Create NavigationAgent2D
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	nav_agent.radius = 24.0
	nav_agent.avoidance_enabled = true
	nav_agent.max_neighbors = 6
	nav_agent.neighbor_distance = 120.0
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(nav_agent)
	await get_tree().process_frame
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	var players = get_tree().get_nodes_in_group("player")
	if players.size() > 0:
		player = players[0]

func _physics_process(delta: float) -> void:
	if player and is_instance_valid(player) and player.visible:
		do_movement(delta)
		move_and_slide()
		# Continuous contact damage
		if touching_player:
			contact_tick_timer -= delta
			if contact_tick_timer <= 0:
				contact_tick_timer = contact_tick_rate
				if player.has_method("take_damage"):
					player.take_damage(contact_damage)

func _update_nav_target() -> void:
	if nav_agent and player and is_instance_valid(player):
		nav_agent.target_position = player.global_position

func get_nav_direction() -> Vector2:
	if not nav_agent:
		if player and is_instance_valid(player):
			return (player.global_position - global_position).normalized()
		return Vector2.ZERO

	if nav_agent.is_navigation_finished():
		if player and is_instance_valid(player):
			return (player.global_position - global_position).normalized()
		return Vector2.ZERO

	# Path smoothing: find the furthest visible waypoint and aim for it
	var path := nav_agent.get_current_navigation_path()
	var path_idx := nav_agent.get_current_navigation_path_index()
	var space_state := get_world_2d().direct_space_state
	var best_target := nav_agent.get_next_path_position()

	if space_state and path.size() > 0:
		# Check from furthest waypoint backwards — only test against walls (layer 1)
		# Use a margin so the shortcut doesn't hug walls too closely
		var margin := 16.0
		for i in range(path.size() - 1, path_idx, -1):
			var dir_to_wp := (path[i] - global_position).normalized()
			var perp_offset := Vector2(-dir_to_wp.y, dir_to_wp.x) * margin
			var query_l := PhysicsRayQueryParameters2D.create(global_position + perp_offset, path[i] + perp_offset, 1)
			var query_r := PhysicsRayQueryParameters2D.create(global_position - perp_offset, path[i] - perp_offset, 1)
			var result_l := space_state.intersect_ray(query_l)
			var result_r := space_state.intersect_ray(query_r)
			if result_l.is_empty() and result_r.is_empty():
				best_target = path[i]
				break

	return (best_target - global_position).normalized()

func do_movement(delta: float) -> void:
	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		_update_nav_target()

	# Stuck detection: if barely moved in 0.5s, try wall-aware escape
	_stuck_timer += delta
	if _stuck_timer >= 0.5:
		var dist_moved := global_position.distance_to(_last_pos)
		if dist_moved < 5.0 and player and global_position.distance_to(player.global_position) > 50.0:
			var to_player := (player.global_position - global_position).normalized()
			var perp := Vector2(-to_player.y, to_player.x)
			# Test both perpendicular directions — pick the one without a wall
			var space_state := get_world_2d().direct_space_state
			var probe_dist := 60.0
			var query_pos := PhysicsRayQueryParameters2D.create(global_position, global_position + perp * probe_dist, 1)
			var query_neg := PhysicsRayQueryParameters2D.create(global_position, global_position - perp * probe_dist, 1)
			var hit_pos := space_state.intersect_ray(query_pos)
			var hit_neg := space_state.intersect_ray(query_neg)
			var escape_dir: Vector2
			if hit_pos.is_empty() and hit_neg.is_empty():
				# Both clear — pick randomly
				escape_dir = perp * (1.0 if randf() > 0.5 else -1.0)
			elif hit_pos.is_empty():
				escape_dir = perp
			elif hit_neg.is_empty():
				escape_dir = -perp
			else:
				# Both blocked — back away from player
				escape_dir = -to_player
			velocity = (to_player * 0.3 + escape_dir * 0.7).normalized() * move_speed * 1.5
			_nav_update_timer = 0.0
		_last_pos = global_position
		_stuck_timer = 0.0

	var dir := get_nav_direction()
	var desired_velocity := dir * move_speed
	if nav_agent and nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired_velocity)
	else:
		velocity = desired_velocity

func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity


func take_damage(amount: int) -> void:
	current_hp -= amount
	flash_white()
	AudioManager.play_sfx("enemy_hit")
	if current_hp <= 0:
		die()

func flash_white() -> void:
	modulate = Color(5, 5, 5, 1)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.1)

func die() -> void:
	AudioManager.play_sfx("enemy_kill")
	enemy_killed.emit(global_position, enemy_type)
	# Give score to player
	if player and player.has_method("add_score"):
		player.add_score(score_value)
	_try_drop_defrag()
	queue_free()

func _try_drop_defrag() -> void:
	var chance := defrag_drop_chance
	if player and "upgrade_defrag_drop_bonus" in player:
		chance += player.upgrade_defrag_drop_bonus
	if randf() < chance:
		var scene: PackedScene = preload("res://scenes/effects/defrag_pickup.tscn")
		var pickup = scene.instantiate()
		pickup.global_position = global_position
		get_tree().current_scene.call_deferred("add_child", pickup)

func _on_hit_player(body: Node2D) -> void:
	if body.is_in_group("player"):
		touching_player = true
		contact_tick_timer = 0.0  # Damage immediately on first contact
		if body.has_method("take_damage"):
			body.take_damage(contact_damage)

func _on_hit_player_exited(body: Node2D) -> void:
	if body.is_in_group("player"):
		touching_player = false
