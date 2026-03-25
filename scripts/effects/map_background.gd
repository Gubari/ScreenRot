extends Sprite2D

@export var texture_path: String = "res://assets/sprites/background/map_bg.png"

func _ready() -> void:
	var tex := load(texture_path)
	if tex is Texture2D:
		texture = tex
