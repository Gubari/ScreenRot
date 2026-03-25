extends Node2D

@export var grid_size: int = 40
@export var grid_color: Color = Color(0.08, 0.15, 0.25, 0.6)
@export var border_color: Color = Color(0, 0.8, 1.0, 0.7)
@export var border_width: float = 2.0
@export var dot_color: Color = Color(0.1, 0.3, 0.5, 0.5)

func _draw() -> void:
	var vs := get_viewport_rect().size
	# Grid lines
	for x in range(0, int(vs.x) + 1, grid_size):
		draw_line(Vector2(x, 0), Vector2(x, vs.y), grid_color, 1.0)
	for y in range(0, int(vs.y) + 1, grid_size):
		draw_line(Vector2(0, y), Vector2(vs.x, y), grid_color, 1.0)
	# Bright dots at intersections
	for x in range(0, int(vs.x) + 1, grid_size):
		for y in range(0, int(vs.y) + 1, grid_size):
			draw_circle(Vector2(x, y), 1.5, dot_color)
	# Arena border
	draw_rect(Rect2(0, 0, vs.x, vs.y), border_color, false, border_width)
