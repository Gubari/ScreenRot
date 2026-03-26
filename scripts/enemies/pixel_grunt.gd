extends EnemyBase

func _ready() -> void:
	enemy_type = "pixel_grunt"
	super._ready()

func do_movement(delta: float) -> void:
	super.do_movement(delta)
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = velocity.x < 0.0
