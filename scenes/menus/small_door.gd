extends AnimatedSprite2D

@export var trigger_distance := 120.0

var _runner: Node2D
var _played := false

func _ready() -> void:
	_runner = get_node("../../FloorLayer/RunningPlayerLight")
	animation_finished.connect(_on_animation_finished)
	stop()
	frame = 0

func _process(_delta: float) -> void:
	if not _runner:
		return
	var close_enough: bool = abs(_runner.global_position.x - global_position.x) < trigger_distance
	if close_enough and not _played:
		_played = true
		frame = 0
		play("default")
	elif not close_enough and _played:
		_played = false

func _on_animation_finished() -> void:
	stop()
