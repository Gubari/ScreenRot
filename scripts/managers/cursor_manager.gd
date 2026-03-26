extends Node

var crosshair_texture: Texture2D
var arrow_texture: Texture2D
var pointer_texture: Texture2D

func _ready() -> void:
	crosshair_texture = _scale_texture(load("res://assets/sprites/crosshair/tile_0035.png"), 1.5)
	arrow_texture = _create_arrow()
	pointer_texture = _create_pointer()
	set_menu_cursor()

func set_crosshair() -> void:
	Input.set_custom_mouse_cursor(crosshair_texture, Input.CURSOR_ARROW, crosshair_texture.get_size() / 2.0)
	Input.set_custom_mouse_cursor(crosshair_texture, Input.CURSOR_POINTING_HAND, crosshair_texture.get_size() / 2.0)

func _scale_texture(tex: Texture2D, factor: float) -> ImageTexture:
	var img := tex.get_image()
	var new_size := Vector2i(int(img.get_width() * factor), int(img.get_height() * factor))
	img.resize(new_size.x, new_size.y, Image.INTERPOLATE_NEAREST)
	return ImageTexture.create_from_image(img)

func set_menu_cursor() -> void:
	Input.set_custom_mouse_cursor(arrow_texture, Input.CURSOR_ARROW, Vector2.ZERO)
	Input.set_custom_mouse_cursor(pointer_texture, Input.CURSOR_POINTING_HAND, Vector2(4, 0))

# --- Cursor generation ---
# Each cursor is drawn on a grid where 1 cell = 2x2 pixels.
# "O" = outline (dark), "F" = fill (bright terminal green-white)

func _bake(grid: Array[String], size: int) -> ImageTexture:
	var img := Image.create(size, size, false, Image.FORMAT_RGBA8)
	img.fill(Color.TRANSPARENT)
	var outline_col := Color(0.06, 0.06, 0.1, 1.0)
	var fill_col := Color(0.78, 0.85, 0.82, 1.0)  # warm terminal white-green
	for y in grid.size():
		var row: String = grid[y]
		for x in row.length():
			var c := row[x]
			if c == "O" or c == "F":
				var col: Color = outline_col if c == "O" else fill_col
				for dy in 2:
					for dx in 2:
						var px := x * 2 + dx
						var py := y * 2 + dy
						if px < size and py < size:
							img.set_pixel(px, py, col)
	return ImageTexture.create_from_image(img)

func _create_arrow() -> ImageTexture:
	# 11 wide x 15 tall grid = 22x30 pixels
	var grid: Array[String] = [
		"O..........",  # 0  tip
		"OO.........",  # 1
		"OFO........",  # 2
		"OFFO.......",  # 3
		"OFFFO......",  # 4
		"OFFFFO.....",  # 5
		"OFFFFFO....",  # 6
		"OFFFFFFO...",  # 7
		"OFFFFFFFO..",  # 8
		"OFFFFFFFFO.",  # 9
		"OFFFFFOOOOO",  # 10  base of arrow body
		"OFFOOFO....",  # 11
		"OFO.OFFO...",  # 12
		"OO..OFFO...",  # 13
		".....OOO...",  # 14
	]
	return _bake(grid, 32)

func _create_pointer() -> ImageTexture:
	# Pointing hand - index finger up
	var grid: Array[String] = [
		"....OO.........",  # 0
		"...OFFO........",  # 1
		"...OFFO........",  # 2
		"...OFFO........",  # 3
		"...OFFO........",  # 4
		"...OFFOO.OO....",  # 5
		"...OFFFOFFFO...",  # 6
		"...OFFFOFFFO...",  # 7
		"OO.OFFFOFFFO...",  # 8
		"OFOOFFFFFFFFFOO",  # 9
		"OFFOFFFFFFFFFO.",  # 10
		".OFFFFFFFFFFFO.",  # 11
		".OFFFFFFFFFFO..",  # 12
		"..OFFFFFFFFO...",  # 13
		"..OFFFFFFFO....",  # 14
		"...OOOOOOO.....",  # 15
	]
	return _bake(grid, 32)
