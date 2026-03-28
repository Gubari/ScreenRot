extends Node2D

signal all_enemies_dead()
signal enemy_killed_global(pos: Vector2, type: String)

var enemy_scenes: Dictionary = {}
var toxic_fly_scene: PackedScene = preload("res://scenes/enemies/toxic_fly.tscn")
var enemies_alive: int = 0
var spawn_queue: Array = []
var spawning: bool = false
## Clock for comparing against absolute spawn timestamps.
var _wave_elapsed: float = 0.0
## Absolute timestamp (seconds from wave start) for the next queued group.
var _next_spawn_at: float = 0.0

# Map bounds (set by game_manager after map generation)
var map_rect: Rect2 = Rect2()
# How far outside camera to spawn (set by game_manager from WaveManager)
var spawn_margin: float = 96.0
# Reference to dungeon map for walkability checks
var dungeon_map: Node2D = null
# If true, spawn enemies at center_position instead of around the camera
var spawn_in_center: bool = false
# World position used as spawn origin when spawn_in_center is true
var center_position: Vector2 = Vector2.ZERO

func _ready() -> void:
	enemy_scenes = {
		"pixel_grunt": preload("res://scenes/enemies/pixel_grunt.tscn"),
		"static_walker": preload("res://scenes/enemies/static_walker.tscn"),
		"bit_bug": preload("res://scenes/enemies/bit_bug.tscn"),
		"toxic_fly": preload("res://scenes/enemies/toxic_fly_egg.tscn"),
		"bloatware_boss": preload("res://scenes/enemies/bloatware_boss.tscn"),
	}


func _spawn_burst(entry: Dictionary) -> void:
	var t: String = entry["type"]
	var n: int = int(entry["count"])
	for _i in n:
		_spawn_one(t)


func _sort_spawn_queue_by_time() -> void:
	if spawn_queue.is_empty():
		return
	for i in range(spawn_queue.size()):
		(spawn_queue[i] as Dictionary)["_spawn_ix"] = i
	spawn_queue.sort_custom(func(a: Variant, b: Variant) -> bool:
		var da: float = float((a as Dictionary).get("delay", 0.0))
		var db: float = float((b as Dictionary).get("delay", 0.0))
		if da != db:
			return da < db
		return int((a as Dictionary)["_spawn_ix"]) < int((b as Dictionary)["_spawn_ix"])
		)
	for e in spawn_queue:
		(e as Dictionary).erase("_spawn_ix")


func _append_queue_with_offset(queue: Array, offset_seconds: float) -> void:
	for raw in queue:
		var e: Dictionary = (raw as Dictionary).duplicate(true)
		e["delay"] = float(e.get("delay", 0.0)) + offset_seconds
		spawn_queue.append(e)


func _process(delta: float) -> void:
	if not spawning:
		return
	if spawn_queue.is_empty():
		spawning = false
		return

	_wave_elapsed += delta

	while spawning and not spawn_queue.is_empty():
		var head: Dictionary = spawn_queue[0]
		var t_fire: float = float(head.get("delay", 0.0))
		if _wave_elapsed < t_fire:
			break
		spawn_queue.pop_front()
		_spawn_burst(head)

	if spawn_queue.is_empty():
		spawning = false
	else:
		_next_spawn_at = float((spawn_queue[0] as Dictionary).get("delay", 0.0))


func start_spawning(queue: Array) -> void:
	enemies_alive = 0
	spawn_queue.clear()
	_append_queue_with_offset(queue, 0.0)
	_sort_spawn_queue_by_time()
	_wave_elapsed = 0.0
	_next_spawn_at = 0.0
	if spawn_queue.is_empty():
		spawning = false
		return
	_next_spawn_at = float((spawn_queue[0] as Dictionary).get("delay", 0.0))
	spawning = true


func add_spawning(queue: Array) -> void:
	var was_idle: bool = not spawning
	if was_idle:
		_wave_elapsed = 0.0
		_next_spawn_at = 0.0
	_append_queue_with_offset(queue, _wave_elapsed)
	_sort_spawn_queue_by_time()
	if spawn_queue.is_empty():
		spawning = false
		return
	spawning = true
	_next_spawn_at = float((spawn_queue[0] as Dictionary).get("delay", 0.0))

func _spawn_one(type: String) -> void:
	if not enemy_scenes.has(type):
		return
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

	# Fallback: random walkable position anywhere on the map
	return _get_any_walkable_position()


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

	# If spawn_in_center is set, spawn exactly at the center position.
	if spawn_in_center:
		return center_position

	# Spawn at spawn_margin distance from camera center, on walkable tiles.
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

	# Fallback: random walkable position anywhere on the map
	return _get_any_walkable_position()

func _get_any_walkable_position() -> Vector2:
	var margin := 32.0
	for _attempt in 100:
		var pos := Vector2(
			randf_range(map_rect.position.x + margin, map_rect.end.x - margin),
			randf_range(map_rect.position.y + margin, map_rect.end.y - margin)
		)
		if _is_walkable(pos):
			return pos
	return map_rect.get_center()

func _is_walkable(pos: Vector2) -> bool:
	if dungeon_map and dungeon_map.has_method("is_walkable"):
		return dungeon_map.is_walkable(pos)
	return true

func _living_boss_blocks_wave_clear() -> bool:
	var enemies_node := get_parent().get_node_or_null("Enemies")
	if enemies_node == null:
		return false
	for n in enemies_node.get_children():
		if n is BossBase:
			var b := n as BossBase
			if b.is_dying:
				continue
			if b.current_hp > 0:
				return true
	return false


func _on_enemy_killed(pos: Vector2, type: String) -> void:
	enemy_killed_global.emit(pos, type)
	enemies_alive = maxi(enemies_alive - 1, 0)
	if enemies_alive == 0 and not spawning and spawn_queue.size() == 0:
		# Brojač može biti 0 dok boss još živi (npr. toxic jaje → muha bez enemy_killed na hatch).
		# Na boss talasu to je inače odmah "wave cleared" + game over jer nema sledećeg talasa.
		if _living_boss_blocks_wave_clear():
			return
		all_enemies_dead.emit()

func get_enemy_count() -> int:
	return enemies_alive


func interrupt_scheduled_spawns() -> void:
	spawning = false
	_wave_elapsed = 0.0
	_next_spawn_at = 0.0
