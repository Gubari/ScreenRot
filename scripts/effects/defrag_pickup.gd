extends Area2D

signal collected()

@export var lifetime: float = 5.0
@export var defrag_percent: float = 35.0
@export var pickup_radius_multiplier: float = 1.35

var _lifetime_timer: float = 0.0

func _ready() -> void:
	add_to_group("defrag_pickups")
	collision_layer = 0
	collision_mask = 1  # detect player
	_scale_pickup_radius()
	_lifetime_timer = lifetime
	# Pulse animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.3, 1.3), 0.5).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.5).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	_lifetime_timer -= delta
	# Flash when about to expire (last 2 seconds)
	if _lifetime_timer <= 2.0:
		visible = fmod(_lifetime_timer, 0.3) > 0.15
	if _lifetime_timer <= 0.0:
		queue_free()

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		AudioManager.play_sfx("defrag")
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
