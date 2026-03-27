extends AnimatedSprite2D

@export var speed := 60.0
@export var y_position := 200.0

var _screen_width: float

func _ready() -> void:
	_screen_width = get_viewport_rect().size.x
	play("run")

func _process(delta: float) -> void:
	position.x += speed * delta
	if position.x > _screen_width + 100.0:
		position.x = -100.0
