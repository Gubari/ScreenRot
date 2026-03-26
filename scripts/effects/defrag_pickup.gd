extends Area2D

signal collected()

@export var lifetime: float = 5.0
@export var defrag_percent: float = 35.0

var _lifetime_timer: float = 0.0

func _ready() -> void:
	add_to_group("defrag_pickups")
	collision_layer = 0
	collision_mask = 1  # detect player
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
		# Clear debris on the overlay
		var overlay = get_tree().get_first_node_in_group("debris_overlay")
		if overlay and overlay.has_method("defrag_clear"):
			overlay.defrag_clear(defrag_percent)
		AudioManager.play_sfx("defrag")
		queue_free()
