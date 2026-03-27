extends AnimatedSprite2D

const CREDIT_AMOUNT := 3
const CREDIT_LIFETIME := 2.0

static var _opened_chests: Array[NodePath] = []

var _opened := false

func _ready() -> void:
	var path := get_path()
	if path in _opened_chests:
		_opened = true
		play("open")
	else:
		play("closed")

func _input(event: InputEvent) -> void:
	if _opened:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var local_mouse := to_local(get_global_mouse_position())
		if abs(local_mouse.x) <= 48 and abs(local_mouse.y) <= 48:
			_open()

func _open() -> void:
	_opened = true
	_opened_chests.append(get_path())
	play("open")
	AudioManager.play_sfx("coin_collect")
	SaveManager.add_credits(CREDIT_AMOUNT)
	_spawn_credits()

func _spawn_credits() -> void:
	var props := load("res://assets/sprites/Tech Dungeon Roguelite - Asset Pack (v7)/Props and Items/props and items x3.png")
	for i in CREDIT_AMOUNT:
		var tex := AtlasTexture.new()
		tex.atlas = props
		tex.region = Rect2(864, 672, 96, 96)
		var credit := Sprite2D.new()
		credit.texture = tex
		credit.position = position + Vector2(randf_range(-20, 20), -10)
		get_parent().add_child(credit)
		_animate_credit(credit)

func _animate_credit(credit: Sprite2D) -> void:
	var start := credit.position
	var spread_x := randf_range(30, 60) * (1.0 if randf() > 0.5 else -1.0)
	var land := start + Vector2(spread_x, randf_range(40, 80))
	var duration := randf_range(0.5, 0.7)

	var arc_height := randf_range(40.0, 60.0)
	var tween := create_tween()
	tween.tween_method(func(t: float):
		var x := lerpf(start.x, land.x, t)
		var y := lerpf(start.y, land.y, t) - sin(t * PI) * arc_height
		credit.position = Vector2(x, y)
	, 0.0, 1.0, duration).set_trans(Tween.TRANS_LINEAR)

	await get_tree().create_timer(CREDIT_LIFETIME).timeout
	var fade := create_tween()
	fade.tween_property(credit, "modulate:a", 0.0, 0.5)
	await fade.finished
	credit.queue_free()
