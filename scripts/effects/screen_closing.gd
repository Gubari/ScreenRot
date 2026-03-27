extends CanvasLayer

## Controls the 4 black bars that close in from the screen edges.
## screen_percent = 100 means full visibility, 0 means fully black.

signal screen_percent_changed(percent: float)
signal screen_fully_closed()

var screen_percent: float = 100.0
var shrink_rate: float = 0.0  # percent per second lost
var _active: bool = false

@onready var top: ColorRect = $Top
@onready var bottom: ColorRect = $Bottom
@onready var left_bar: ColorRect = $Left
@onready var right_bar: ColorRect = $Right

func _ready() -> void:
	layer = 100
	_update_bars()

func _process(delta: float) -> void:
	if not _active:
		return
	if shrink_rate > 0.0:
		screen_percent -= shrink_rate * delta
		screen_percent = maxf(screen_percent, 0.0)
		_update_bars()
		screen_percent_changed.emit(screen_percent)
		if screen_percent <= 0.0:
			_active = false
			screen_fully_closed.emit()

func start(rate: float) -> void:
	shrink_rate = rate
	_active = true

func stop() -> void:
	_active = false
	shrink_rate = 0.0

func restore(amount: float) -> void:
	screen_percent = minf(screen_percent + amount, 100.0)
	_update_bars()
	screen_percent_changed.emit(screen_percent)

func reset_to_full() -> void:
	_active = false
	shrink_rate = 0.0
	var tw := create_tween()
	tw.tween_method(_set_percent, screen_percent, 100.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_percent_immediate(value: float) -> void:
	screen_percent = clampf(value, 0.0, 100.0)
	_update_bars()
	screen_percent_changed.emit(screen_percent)

func _set_percent(value: float) -> void:
	screen_percent = value
	_update_bars()
	screen_percent_changed.emit(screen_percent)

## Returns the visible (non-covered) rectangle in viewport coordinates.
func get_visible_area() -> Rect2:
	var vp_size := get_viewport().get_visible_rect().size
	var cover := (1.0 - screen_percent / 100.0) * 0.5
	var bar_h := vp_size.y * cover
	var bar_w := vp_size.x * cover
	return Rect2(bar_w, bar_h, vp_size.x - bar_w * 2.0, vp_size.y - bar_h * 2.0)

func _update_bars() -> void:
	var vp_size := get_viewport().get_visible_rect().size
	# fraction of screen covered on each side (0 = no bar, 0.5 = fully closed)
	var cover := (1.0 - screen_percent / 100.0) * 0.5

	var bar_h := vp_size.y * cover
	var bar_w := vp_size.x * cover

	top.position = Vector2.ZERO
	top.size = Vector2(vp_size.x, bar_h)

	bottom.position = Vector2(0, vp_size.y - bar_h)
	bottom.size = Vector2(vp_size.x, bar_h)

	left_bar.position = Vector2.ZERO
	left_bar.size = Vector2(bar_w, vp_size.y)

	right_bar.position = Vector2(vp_size.x - bar_w, 0)
	right_bar.size = Vector2(bar_w, vp_size.y)
