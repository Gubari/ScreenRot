extends Area2D

signal collected(value: float)

@export var restore_value: float = 15.0
var _tween: Tween

func _ready() -> void:
	add_to_group("screen_fragments")
	collision_layer = 0
	collision_mask = 1  # detect player
	# Pulse animation
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "scale", Vector2(1.2, 1.2), 0.4).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", Vector2(0.8, 0.8), 0.4).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(restore_value)
		queue_free()
