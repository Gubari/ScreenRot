extends Area2D

signal collected()

@export var credit_value: int = 1

func _ready() -> void:
	add_to_group("coin_pickups")
	collision_layer = 0
	collision_mask = 1  # detect player
	# Register credits handler here: coins are added via call_deferred after enemy_killed,
	# so GameManager._connect_coin_pickups() often runs before this node exists.
	var game_root := get_tree().current_scene
	if game_root and game_root.has_method("_on_coin_pickup_collected"):
		if not collected.is_connected(game_root._on_coin_pickup_collected):
			collected.connect(game_root._on_coin_pickup_collected)
	# Pulse animation
	var tween = create_tween().set_loops()
	tween.tween_property(self, "scale", Vector2(1.1, 1.1), 0.4).set_trans(Tween.TRANS_SINE)
	tween.tween_property(self, "scale", Vector2(0.9, 0.9), 0.4).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if body.is_in_group("player"):
		collected.emit()
		queue_free()
