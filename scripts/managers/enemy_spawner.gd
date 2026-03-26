extends Node2D

signal all_enemies_dead()
signal enemy_killed_global(pos: Vector2, type: String)

var enemy_scenes: Dictionary = {}
var enemies_alive: int = 0
var spawn_queue: Array = []
var spawn_timer: float = 0.0
var spawning: bool = false

# Map bounds (set by game_manager after map generation)
var map_rect: Rect2 = Rect2()

func _ready() -> void:
	enemy_scenes = {
		"pixel_grunt": preload("res://scenes/enemies/pixel_grunt.tscn"),
		"static_walker": preload("res://scenes/enemies/static_walker.tscn"),
		"bit_bug": preload("res://scenes/enemies/bit_bug.tscn"),
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
		enemy.global_position = _get_spawn_position()
		enemy.enemy_killed.connect(_on_enemy_killed)
		get_parent().get_node("Enemies").add_child(enemy)
		enemies_alive += 1

func _get_spawn_position() -> Vector2:
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

	# Spawn off-camera but within map bounds
	var camera := get_viewport().get_camera_2d()
	if not camera:
		return map_rect.get_center()

	var vp_size := get_viewport_rect().size
	var cam_rect := Rect2(camera.global_position - vp_size / 2.0, vp_size)
	var margin := 96.0  # One tile outside camera

	# Try to find a position inside map but outside camera view
	for _attempt in 20:
		var pos := Vector2(
			randf_range(map_rect.position.x + margin, map_rect.end.x - margin),
			randf_range(map_rect.position.y + margin, map_rect.end.y - margin)
		)
		if not cam_rect.has_point(pos):
			return pos

	# Fallback: spawn at edge of camera view
	var side := randi() % 4
	var expanded := cam_rect.grow(margin)
	match side:
		0: return Vector2(randf_range(expanded.position.x, expanded.end.x), expanded.position.y)
		1: return Vector2(randf_range(expanded.position.x, expanded.end.x), expanded.end.y)
		2: return Vector2(expanded.position.x, randf_range(expanded.position.y, expanded.end.y))
		3: return Vector2(expanded.end.x, randf_range(expanded.position.y, expanded.end.y))
	return expanded.position

func _on_enemy_killed(pos: Vector2, type: String) -> void:
	enemy_killed_global.emit(pos, type)
	enemies_alive -= 1
	if enemies_alive <= 0 and not spawning and spawn_queue.size() == 0:
		all_enemies_dead.emit()

func get_enemy_count() -> int:
	return enemies_alive
