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
	_map_rect = _calc_map_rect()
	map_ready.emit(_map_rect)


func get_map_rect() -> Rect2:
	return _map_rect


func get_player_spawn() -> Vector2:
	return Vector2(_map_rect.size.x / 2.0, _map_rect.size.y / 2.0)


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
	# Create a StaticBody2D with collision for every tile on the WallLayer.
	var body := StaticBody2D.new()
	body.collision_layer = 1 | 2
	body.collision_mask = 0
	add_child(body)

	for cell in wall_layer.get_used_cells() + props_collision_layer.get_used_cells():
		var shape := CollisionShape2D.new()
		var rect := RectangleShape2D.new()
		rect.size = Vector2(TILE_SIZE, TILE_SIZE)
		shape.shape = rect
		shape.position = Vector2(
			cell.x * TILE_SIZE + TILE_SIZE / 2.0,
			cell.y * TILE_SIZE + TILE_SIZE / 2.0
		)
		body.add_child(shape)
