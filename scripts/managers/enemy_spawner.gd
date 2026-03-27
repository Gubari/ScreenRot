extends Node2D

signal all_enemies_dead()
signal enemy_killed_global(pos: Vector2, type: String)

var enemy_scenes: Dictionary = {}
var toxic_fly_scene: PackedScene = preload("res://scenes/enemies/toxic_fly.tscn")
var enemies_alive: int = 0
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var spawning: bool = false

# Map bounds (set by game_manager after map generation)
var map_rect: Rect2 = Rect2()
# How far outside camera to spawn (set by game_manager from WaveManager)
var spawn_margin: float = 96.0
# Reference to dungeon map for walkability checks
var dungeon_map: Node2D = null

func _ready() -> void:
	enemy_scenes = {
		"pixel_grunt": preload("res://scenes/enemies/pixel_grunt.tscn"),
		"static_walker": preload("res://scenes/enemies/static_walker.tscn"),
		"bit_bug": preload("res://scenes/enemies/bit_bug.tscn"),
		"toxic_fly": preload("res://scenes/enemies/toxic_fly_egg.tscn"),
		"bloatware_boss": preload("res://scenes/enemies/bloatware_boss.tscn"),
	}

func _process(delta: float) -> void:
	if spawning and spawn_queue.size() > 0:
		spawn_timer -= delta
		if spawn_timer <= 0:
			var next = spawn_queue.pop_front()
			_do_spawn(next.type, next.count)
			if spawn_queue.size() > 0:
				spawn_timer = spawn_queue[0].delay if spawn_queue[0].has("delay") else 1.0
			else:
				spawning = false

func start_spawning(queue: Array) -> void:
	spawn_queue = queue.duplicate(true)
	spawning = true
	if spawn_queue.size() > 0:
		spawn_timer = spawn_queue[0].get("delay", 0.0)

func _do_spawn(type: String, count: int) -> void:
	if not enemy_scenes.has(type):
		return
	for i in range(count):
		var enemy = enemy_scenes[type].instantiate()
		enemy.global_position = _get_spawn_position(type)
		enemy.enemy_killed.connect(_on_enemy_killed)
		if enemy.has_signal("hatch_requested"):
			enemy.hatch_requested.connect(_on_toxic_fly_egg_hatched)
		get_parent().get_node("Enemies").add_child(enemy)
		enemies_alive += 1

func _on_toxic_fly_egg_hatched(pos: Vector2) -> void:
	var fly := toxic_fly_scene.instantiate()
	fly.global_position = pos
	fly.enemy_killed.connect(_on_enemy_killed)
	get_parent().get_node("Enemies").add_child(fly)

func _get_spawn_position(type: String = "") -> Vector2:
	if type == "toxic_fly":
		return _get_spawn_position_in_player_viewport()
	return _get_spawn_position_default()


func _get_spawn_position_in_player_viewport() -> Vector2:
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return _get_spawn_position_default()

	var vp_size := get_viewport().get_visible_rect().size
	var half_w := (float(vp_size.x) / cam.zoom.x) * 0.5
	var half_h := (float(vp_size.y) / cam.zoom.y) * 0.5
	var inset := 32.0
	var center := cam.get_screen_center_position()
	var map_margin := 16.0

	for _attempt in 60:
		var pos := center + Vector2(
			randf_range(-half_w + inset, half_w - inset),
			randf_range(-half_h + inset, half_h - inset)
		)
		if map_rect.size != Vector2.ZERO:
			if not map_rect.grow(-map_margin).has_point(pos):
				continue
		if _is_walkable(pos):
			return pos

	# Fallback: unutra viewporta, clamp na mapu ako postoji
	var fallback_pos := center + Vector2(
		randf_range(-half_w + inset, half_w - inset),
		randf_range(-half_h + inset, half_h - inset)
	)
	if map_rect.size != Vector2.ZERO:
		fallback_pos.x = clampf(fallback_pos.x, map_rect.position.x + map_margin, map_rect.end.x - map_margin)
		fallback_pos.y = clampf(fallback_pos.y, map_rect.position.y + map_margin, map_rect.end.y - map_margin)
	return fallback_pos


func _get_spawn_position_default() -> Vector2:
	if map_rect.size == Vector2.ZERO:
		# Fallback to old viewport-edge spawning
		var vp = get_viewport_rect().size
		var margin: float = 40.0
		var side = randi() % 4
		match side:
			0: return Vector2(randf_range(margin, vp.x - margin), -margin)
			1: return Vector2(randf_range(margin, vp.x - margin), vp.y + margin)
			2: return Vector2(-margin, randf_range(margin, vp.y - margin))
			3: return Vector2(vp.x + margin, randf_range(margin, vp.y - margin))
		return Vector2(-margin, -margin)

	# Spawn at spawn_margin distance from camera center, on walkable tiles
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return map_rect.get_center()

	var center := camera.global_position
	var map_margin := 16.0

	for _attempt in 40:
		var angle := randf() * TAU
		var pos := center + Vector2(cos(angle), sin(angle)) * spawn_margin
		if map_rect.grow(-map_margin).has_point(pos) and _is_walkable(pos):
			return pos

	# Fallback: clamp to map bounds
	var fb_angle := randf() * TAU
	var fallback_pos := center + Vector2(cos(fb_angle), sin(fb_angle)) * spawn_margin
	fallback_pos.x = clampf(fallback_pos.x, map_rect.position.x + map_margin, map_rect.end.x - map_margin)
	fallback_pos.y = clampf(fallback_pos.y, map_rect.position.y + map_margin, map_rect.end.y - map_margin)
	return fallback_pos

func _is_walkable(pos: Vector2) -> bool:
	if dungeon_map and dungeon_map.has_method("is_walkable"):
		return dungeon_map.is_walkable(pos)
	return true

func _on_enemy_killed(pos: Vector2, type: String) -> void:
	enemy_killed_global.emit(pos, type)
	enemies_alive -= 1
	if enemies_alive <= 0 and not spawning and spawn_queue.size() == 0:
		all_enemies_dead.emit()

func get_enemy_count() -> int:
	return enemies_alive
