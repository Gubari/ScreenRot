extends Area2D

signal collected(value: float)

@export var restore_value: float = 15.0
@export var pickup_radius_multiplier: float = 1.35
## Uniform scale for sprite + collision (pulse animation stays relative to this).
@export var pickup_visual_scale: Vector2 = Vector2(2, 2)
var _tween: Tween

func _ready() -> void:
	scale = pickup_visual_scale
	var pulse_base := scale
	add_to_group("screen_fragments")
	collision_layer = 0
	collision_mask = 1  # detect player
	_scale_pickup_radius()
	# Pulse animation (relative to scene scale)
	_tween = create_tween().set_loops()
	_tween.tween_property(self, "scale", pulse_base * 1.2, 0.4).set_trans(Tween.TRANS_SINE)
	_tween.tween_property(self, "scale", pulse_base * 0.8, 0.4).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit(restore_value)
		if body.has_method("_on_fragment_body_entered"):
			body._on_fragment_body_entered(self)
		queue_free()


func _scale_pickup_radius() -> void:
	var cs := get_node_or_null("CollisionShape2D") as CollisionShape2D
	if cs == null or cs.shape == null:
		return
	cs.shape = cs.shape.duplicate()
	var shape := cs.shape
	if shape is CircleShape2D:
		(shape as CircleShape2D).radius *= pickup_radius_multiplier
	elif shape is RectangleShape2D:
		(shape as RectangleShape2D).size *= pickup_radius_multiplier
