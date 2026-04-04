extends Node2D

## Vizuelni overlay koji se prikazuje na svakom AI igracu u world-spaceu.
## Predstavlja "viewport" AI igraca koji se suzi od svih 4 strane.
## Dodati kao child node na ai_light.tscn i ai_heavy.tscn.

## Dimenzije viewport pravougaonika u pikselima (16:9 odnos).
const FRAME_W: float = 192.0
const FRAME_H: float = 128.0

## Minimalni screen_percent — nikad ne ide do nule.
const MIN_PERCENT: float = 15.0

## Trenutni procenat vidljivog ekrana (100 = cist, 15 = maksimalno suzeno).
var screen_percent: float = 100.0

## Da li je shrink trenutno aktivan (postavlja manager).
var shrink_active: bool = false


func _draw() -> void:
	var cover := (1.0 - screen_percent / 100.0) * 0.5

	var bar_w := FRAME_W * cover
	var bar_h := FRAME_H * cover

	var left   := -FRAME_W * 0.5
	var top    := -FRAME_H * 0.5
	var right  :=  FRAME_W * 0.5
	var bottom :=  FRAME_H * 0.5

	var col := _get_color()

	# Gornja traka
	draw_rect(Rect2(left, top, FRAME_W, bar_h), col)
	# Donja traka
	draw_rect(Rect2(left, bottom - bar_h, FRAME_W, bar_h), col)
	# Leva traka
	draw_rect(Rect2(left, top, bar_w, FRAME_H), col)
	# Desna traka
	draw_rect(Rect2(right - bar_w, top, bar_w, FRAME_H), col)

	# Okvir (uvek vidljiv, tanak)
	draw_rect(Rect2(left, top, FRAME_W, FRAME_H), _get_frame_color(), false, 1.5)


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


func _get_frame_color() -> Color:
	if screen_percent > 80.0:
		return Color(0.0, 1.0, 0.4, 0.6)   # zelena
	elif screen_percent > 50.0:
		return Color(1.0, 0.85, 0.0, 0.7)  # zuta
	else:
		return Color(1.0, 0.2, 0.1, 0.9)   # crvena


## Poziva other_side_manager svaki frame dok je shrink aktivan.
func apply_shrink(rate: float, delta: float) -> void:
	screen_percent -= rate * delta
	screen_percent = maxf(screen_percent, MIN_PERCENT)
	queue_redraw()


## Poziva se kad AI igrac skupi screen_fragment.
func restore(amount: float) -> void:
	screen_percent = minf(screen_percent + amount, 100.0)
	queue_redraw()


func get_screen_percent() -> float:
	return screen_percent


## Resetuje overlay na pun ekran (npr. na kraju borbe).
func reset() -> void:
	screen_percent = 100.0
	shrink_active = false
	queue_redraw()
