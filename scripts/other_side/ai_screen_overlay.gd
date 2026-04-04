extends Node2D

## Vizuelni overlay koji se prikazuje na svakom AI igracu u world-spaceu.
## Predstavlja "viewport" AI igraca koji se suzi od svih 4 strane.
## Dodati kao child node na ai_light.tscn i ai_heavy.tscn.

## Dimenzije viewport pravougaonika u pikselima (16:9 odnos).
@export var frame_size: Vector2 = Vector2(1280.0, 720.0)
@export var border_thickness: float = 5.0
@export var border_color: Color = Color(0.0, 0.0, 0.0, 1.0)

## Minimalni screen_percent — nikad ne ide do nule.
const MIN_PERCENT: float = 15.0
@export var fade_time: float = 0.15

## Trenutni procenat vidljivog ekrana (100 = cist, 15 = maksimalno suzeno).
var screen_percent: float = 100.0

## Da li je shrink trenutno aktivan (postavlja manager).
var shrink_active: bool = false
var _fade_tween: Tween = null

func _ready() -> void:
	# Hidden by default; appears only when shrink ability is triggered.
	visible = false
	modulate.a = 0.0


func _draw() -> void:
	if not visible:
		return
	var frame_w := frame_size.x
	var frame_h := frame_size.y
	var cover := (1.0 - screen_percent / 100.0) * 0.5

	var bar_w := frame_w * cover
	var bar_h := frame_h * cover

	var left   := -frame_w * 0.5
	var top    := -frame_h * 0.5
	var right  :=  frame_w * 0.5
	var bottom :=  frame_h * 0.5

	var col := _get_color()

	# Gornja traka
	draw_rect(Rect2(left, top, frame_w, bar_h), col)
	# Donja traka
	draw_rect(Rect2(left, bottom - bar_h, frame_w, bar_h), col)
	# Leva traka
	draw_rect(Rect2(left, top, bar_w, frame_h), col)
	# Desna traka
	draw_rect(Rect2(right - bar_w, top, bar_w, frame_h), col)

	# Okvir (uvek vidljiv): crn i podesive debljine.
	var thickness := maxf(border_thickness, 0.0)
	if thickness > 0.0:
		draw_rect(Rect2(left, top, frame_w, frame_h), border_color, false, thickness)


func _get_color() -> Color:
	var t := 1.0 - clampf((screen_percent - MIN_PERCENT) / (100.0 - MIN_PERCENT), 0.0, 1.0)
	var alpha := lerpf(0.0, 0.75, t)
	if screen_percent > 80.0:
		return Color(0.0, 0.0, 0.0, alpha)
	elif screen_percent > 50.0:
		# crna → zuta tint
		return Color(0.15, 0.1, 0.0, alpha)
	else:
		# crna → crvena tint
		return Color(0.2, 0.0, 0.0, alpha)


## Poziva other_side_manager svaki frame dok je shrink aktivan.
func apply_shrink(rate: float, delta: float) -> void:
	if not visible:
		_show_with_fade()
	shrink_active = true
	screen_percent -= rate * delta
	screen_percent = maxf(screen_percent, MIN_PERCENT)
	queue_redraw()


## Poziva se kad AI igrac skupi screen_fragment.
func restore(amount: float) -> void:
	screen_percent = minf(screen_percent + amount, 100.0)
	if screen_percent >= 99.99:
		screen_percent = 100.0
		shrink_active = false
		_hide_with_fade()
	queue_redraw()


func get_screen_percent() -> float:
	return screen_percent


## Poziva manager pri aktivaciji boss shrink ability.
func begin_shrink_cycle() -> void:
	shrink_active = true
	_show_with_fade()
	queue_redraw()


## Poziva manager kad istekne aktivni shrink period.
func end_shrink_cycle() -> void:
	shrink_active = false
	if screen_percent >= 99.99:
		screen_percent = 100.0
		_hide_with_fade()
	queue_redraw()


## Resetuje overlay na pun ekran (npr. na kraju borbe).
func reset() -> void:
	screen_percent = 100.0
	shrink_active = false
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	modulate.a = 0.0
	visible = false
	queue_redraw()


func _show_with_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	visible = true
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 1.0, maxf(fade_time, 0.0))


func _hide_with_fade() -> void:
	if _fade_tween and _fade_tween.is_valid():
		_fade_tween.kill()
	_fade_tween = create_tween()
	_fade_tween.tween_property(self, "modulate:a", 0.0, maxf(fade_time, 0.0))
	_fade_tween.tween_callback(func():
		visible = false
	)
