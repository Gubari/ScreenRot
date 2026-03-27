extends AnimatedSprite2D

signal loop_started

@export var move_down_distance := 150.0
@export var move_right_distance := 300.0
@export var speed := 60.0
@export var start_delay := 0.0

enum State { IDLE, MOVING_DOWN, MOVING_RIGHT }

var _state := State.IDLE
var _target_pos := Vector2.ZERO
var _start_pos := Vector2.ZERO

func _ready() -> void:
	_start_pos = position
	play("run")
	if start_delay > 0.0:
		await get_tree().create_timer(start_delay).timeout
	_start_down()
	loop_started.emit()

func _start_down() -> void:
	_target_pos = position + Vector2(0, move_down_distance)
	_state = State.MOVING_DOWN

func _start_right() -> void:
	_target_pos = position + Vector2(move_right_distance, 0)
	_state = State.MOVING_RIGHT

func _process(delta: float) -> void:
	if _state == State.IDLE:
		return

	position = position.move_toward(_target_pos, speed * delta)

	if position.distance_to(_target_pos) < 1.0:
		position = _target_pos
		match _state:
			State.MOVING_DOWN:
				_start_right()
			State.MOVING_RIGHT:
				position = _start_pos
				_start_down()
				loop_started.emit()
