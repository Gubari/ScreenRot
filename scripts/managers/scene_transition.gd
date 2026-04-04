extends CanvasLayer

var _overlay: ColorRect

# Podaci koji se prenose izmedju scena (other side)
var transfer_score: int = 0
var transfer_credits: int = 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 200
	_overlay = ColorRect.new()
	_overlay.color = Color(0, 0, 0, 0)
	_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
	_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overlay)


func change_scene(path: String) -> void:
	_overlay.mouse_filter = Control.MOUSE_FILTER_STOP
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 1.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func():
		get_tree().change_scene_to_file(path)
		_fade_in()
	)


func _fade_in() -> void:
	var tween := create_tween()
	tween.tween_property(_overlay, "color:a", 0.0, 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(func(): _overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE)
