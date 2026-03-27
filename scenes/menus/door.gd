extends AnimatedSprite2D

@export var patrol_node: NodePath

func _ready() -> void:
	play("default")
	if patrol_node:
		get_node(patrol_node).loop_started.connect(_on_loop_started)

func _on_loop_started() -> void:
	play("default")
