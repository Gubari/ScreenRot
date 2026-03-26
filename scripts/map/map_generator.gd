extends Node2D

## Map controller — reads the hand-edited TileMapLayers and builds collision at runtime.

signal map_ready(map_rect: Rect2)

const TILE_SIZE := 96  # 32px base × 3

@onready var floor_layer: TileMapLayer = $TileMapLayer
@onready var wall_layer: TileMapLayer = $WallLayer

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

func is_walkable(world_pos: Vector2) -> bool:
	var cell := Vector2i(int(floor(world_pos.x / TILE_SIZE)), int(floor(world_pos.y / TILE_SIZE)))
	# Not walkable if there's a wall tile here
	if wall_layer.get_cell_source_id(cell) != -1:
		return false
	# Must be on a floor tile
	return floor_layer.get_cell_source_id(cell) != -1


func _calc_map_rect() -> Rect2:
	# Determine bounds from whichever layer has tiles placed
	var used := floor_layer.get_used_rect()
	var used_w := wall_layer.get_used_rect()
	var merged := used.merge(used_w)
	return Rect2(
		Vector2(merged.position.x * TILE_SIZE, merged.position.y * TILE_SIZE),
		Vector2(merged.size.x * TILE_SIZE, merged.size.y * TILE_SIZE)
	)


func _build_collision() -> void:
	# Create a StaticBody2D with collision for every tile on the WallLayer.
	var body := StaticBody2D.new()
	body.collision_layer = 1 | 2
	body.collision_mask = 0
	add_child(body)

	for cell in wall_layer.get_used_cells():
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(
			cell.x * TILE_SIZE + TILE_SIZE / 2.0,
			cell.y * TILE_SIZE + TILE_SIZE / 2.0
		)
		body.add_child(shape)


func _build_navigation() -> void:
	var wall_cells := {}
	for cell in wall_layer.get_used_cells():
		wall_cells[cell] = true

	var walkable_set := {}
	for cell in floor_layer.get_used_cells():
		if not wall_cells.has(cell):
			walkable_set[cell] = true

	if walkable_set.is_empty():
		return

	# Inset vertices that border walls so nav paths stay away from corners
	const INSET := 20.0

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
