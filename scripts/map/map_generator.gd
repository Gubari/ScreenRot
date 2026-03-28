extends Node2D

## Map controller — reads the hand-edited TileMapLayers and builds collision at runtime.

signal map_ready(map_rect: Rect2)

const TILE_SIZE := 96  # 32px base × 3

@onready var floor_layer: TileMapLayer = $TileMapLayer
@onready var wall_layer: TileMapLayer = $WallLayer
@onready var props_collision_layer: TileMapLayer = $PropsCollisionLayer

var _map_rect: Rect2


func generate() -> void:
	_build_collision()
	_build_navigation()
	_map_rect = _calc_map_rect()
	map_ready.emit(_map_rect)


func get_map_rect() -> Rect2:
	return _map_rect


func get_player_spawn() -> Vector2:
	return Vector2(_map_rect.size.x / 2.0, _map_rect.size.y / 2.0)


func _cell_from_world(world_pos: Vector2) -> Vector2i:
	# Mora lokalno za TileMapLayer — DungeonMap može biti pomeren u sceni.
	var local := floor_layer.to_local(world_pos)
	return Vector2i(int(floor(local.x / float(TILE_SIZE))), int(floor(local.y / float(TILE_SIZE))))


func _cell_center_global(cell: Vector2i) -> Vector2:
	var local := Vector2((float(cell.x) + 0.5) * float(TILE_SIZE), (float(cell.y) + 0.5) * float(TILE_SIZE))
	return floor_layer.to_global(local)


func is_walkable(world_pos: Vector2) -> bool:
	var cell := _cell_from_world(world_pos)
	# Not walkable if there's a wall tile here
	if wall_layer.get_cell_source_id(cell) != -1:
		return false
	# Not walkable if there's a prop with collision here
	if props_collision_layer.get_cell_source_id(cell) != -1:
		return false
	# Must be on a floor tile
	return floor_layer.get_cell_source_id(cell) != -1


## Najbliže walkable polje (centar ćelije) — za pickupe koji bi inače pali na reku / zid.
func snap_to_walkable(world_pos: Vector2, max_radius_cells: int = 56) -> Vector2:
	if is_walkable(world_pos):
		return world_pos
	var origin := _cell_from_world(world_pos)
	var cx := origin.x
	var cy := origin.y
	var max_r := maxi(max_radius_cells, 1)
	for r in range(1, max_r + 1):
		for dx in range(-r, r + 1):
			for dy in range(-r, r + 1):
				if maxi(abs(dx), abs(dy)) != r:
					continue
				var c := Vector2i(cx + dx, cy + dy)
				var wp := _cell_center_global(c)
				if is_walkable(wp):
					return wp
	return world_pos


func _calc_map_rect() -> Rect2:
	# Determine bounds from whichever layer has tiles placed
	var used := floor_layer.get_used_rect()
	var used_w := wall_layer.get_used_rect()
	var used_p := props_collision_layer.get_used_rect()
	var merged := used.merge(used_w).merge(used_p)
	return Rect2(
		Vector2(merged.position.x * TILE_SIZE, merged.position.y * TILE_SIZE),
		Vector2(merged.size.x * TILE_SIZE, merged.size.y * TILE_SIZE)
	)


func _build_collision() -> void:
	var body := StaticBody2D.new()
	# Samo terrain (layer 5) — leteći neprijatelji nemaju terrain u maski, prolaze preko zelenih reka / zidova.
	body.collision_layer = 1 << 4
	body.collision_mask = 0
	add_child(body)

	# Merge adjacent tiles into larger rectangles to avoid seam-snagging
	var all_cells := {}
	for cell in wall_layer.get_used_cells():
		all_cells[cell] = true
	for cell in props_collision_layer.get_used_cells():
		all_cells[cell] = true

	var used := {}
	# Sort cells by y then x for row-first greedy merge
	var sorted_cells := all_cells.keys()
	sorted_cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		if a.y != b.y:
			return a.y < b.y
		return a.x < b.x
	)

	for cell in sorted_cells:
		if used.has(cell):
			continue
		# Expand right as far as possible
		var w := 1
		while all_cells.has(Vector2i(cell.x + w, cell.y)) and not used.has(Vector2i(cell.x + w, cell.y)):
			w += 1
		# Expand down as far as possible
		var h := 1
		var can_expand := true
		while can_expand:
			for dx in range(w):
				var check := Vector2i(cell.x + dx, cell.y + h)
				if not all_cells.has(check) or used.has(check):
					can_expand = false
					break
			if can_expand:
				h += 1
		# Mark all cells in this rect as used
		for dy in range(h):
			for dx in range(w):
				used[Vector2i(cell.x + dx, cell.y + dy)] = true
		# Create merged collision shape
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(w * TILE_SIZE, h * TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(
			cell.x * TILE_SIZE + w * TILE_SIZE / 2.0,
			cell.y * TILE_SIZE + h * TILE_SIZE / 2.0
		)
		body.add_child(shape)


func _build_navigation() -> void:
	var blocked_cells := {}
	for cell in wall_layer.get_used_cells():
		blocked_cells[cell] = true
	for cell in props_collision_layer.get_used_cells():
		blocked_cells[cell] = true

	var walkable_set := {}
	for cell in floor_layer.get_used_cells():
		if not blocked_cells.has(cell):
			walkable_set[cell] = true

	if walkable_set.is_empty():
		return

	# Inset vertices that border walls so nav paths stay away from corners
	const INSET := 38.0

	# First pass: collect all grid corners and compute inset positions
	var corner_pos := {}  # Vector2i -> Vector2 (world position, possibly inset)
	for cell_key in walkable_set:
		var cx: int = cell_key.x
		var cy: int = cell_key.y
		var c0 := Vector2i(cx, cy)
		var c1 := Vector2i(cx + 1, cy)
		var c2 := Vector2i(cx + 1, cy + 1)
		var c3 := Vector2i(cx, cy + 1)
		for c in [c0, c1, c2, c3]:
			if corner_pos.has(c):
				continue
			var base := Vector2(c.x * TILE_SIZE, c.y * TILE_SIZE)
			# 4 cells sharing this corner
			var adj := [
				Vector2i(c.x - 1, c.y - 1),
				Vector2i(c.x,     c.y - 1),
				Vector2i(c.x - 1, c.y),
				Vector2i(c.x,     c.y),
			]
			var offset := Vector2.ZERO
			for a in adj:
				if not walkable_set.has(a):
					var cell_center := Vector2(a.x * TILE_SIZE + TILE_SIZE * 0.5, a.y * TILE_SIZE + TILE_SIZE * 0.5)
					offset += (base - cell_center).normalized()
			if offset.length() > 0.001:
				offset = offset.normalized() * INSET
			corner_pos[c] = base + offset

	# Second pass: build triangulated nav poly
	var nav_region := NavigationRegion2D.new()
	var nav_poly := NavigationPolygon.new()
	var vertex_map := {}
	var vertices := PackedVector2Array()
	var polygons: Array[PackedInt32Array] = []

	for cell_key in walkable_set:
		var cx: int = cell_key.x
		var cy: int = cell_key.y
		var cell_corners := [
			Vector2i(cx, cy),
			Vector2i(cx + 1, cy),
			Vector2i(cx + 1, cy + 1),
			Vector2i(cx, cy + 1),
		]
		var idx: Array[int] = []
		for i in range(4):
			var cc: Vector2i = cell_corners[i]
			if not vertex_map.has(cc):
				vertex_map[cc] = vertices.size()
				vertices.append(corner_pos[cc])
			idx.append(vertex_map[cc])
		polygons.append(PackedInt32Array([idx[0], idx[1], idx[2]]))
		polygons.append(PackedInt32Array([idx[0], idx[2], idx[3]]))

	nav_poly.set_vertices(vertices)
	for poly in polygons:
		nav_poly.add_polygon(poly)

	nav_region.navigation_polygon = nav_poly
	add_child(nav_region)
