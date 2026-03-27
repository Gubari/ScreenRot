extends AnimatedSprite2D

var _on := true

func _ready() -> void:
	play("on")

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse := to_local(get_global_mouse_position())
		var half := Vector2(92, 46)
		if abs(local_mouse.x) <= half.x and abs(local_mouse.y) <= half.y:
			_on = !_on
			play("on" if _on else "off")
