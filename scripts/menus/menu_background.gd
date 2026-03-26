extends Node2D

## Fills the viewport with random floor and wall tiles for a decorative menu background.

const TILE_SIZE := 96

# Floor tile atlas coords from source 0 (dark floor variations)
const FLOOR_TILES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(2, 1),
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(0, 1),  # weighted towards basic floors
]

# Wall tile atlas coords from source 0 (top section of tileset)
const WALL_TILES: Array[Vector2i] = [
	Vector2i(0, 0), Vector2i(1, 0), Vector2i(2, 0),
	Vector2i(3, 0), Vector2i(4, 0), Vector2i(5, 0),
]

@onready var floor_layer: TileMapLayer = $FloorLayer
@onready var wall_layer: TileMapLayer = $WallLayer

func _ready() -> void:
	_fill_background()

func _fill_background() -> void:
	var viewport_size := get_viewport().get_visible_rect().size
	var cols := int(ceil(viewport_size.x / TILE_SIZE)) + 2
	var rows := int(ceil(viewport_size.y / TILE_SIZE)) + 2

	# Offset so tiles start slightly off-screen
	var start_x := -1
	var start_y := -1

	for x in range(start_x, start_x + cols):
		for y in range(start_y, start_y + rows):
			var cell := Vector2i(x, y)
			var tile: Vector2i = FLOOR_TILES[randi() % FLOOR_TILES.size()]
			floor_layer.set_cell(cell, 0, tile)

	# Scatter some wall tiles randomly for visual interest
	var wall_count := int(cols * rows * 0.08)
	for i in wall_count:
		var wx := randi_range(start_x, start_x + cols - 1)
		var wy := randi_range(start_y, start_y + rows - 1)
		var cell := Vector2i(wx, wy)
		var tile: Vector2i = WALL_TILES[randi() % WALL_TILES.size()]
		wall_layer.set_cell(cell, 0, tile)
