extends Control

# ── Prices — edit these to set individual unlock costs ────────
var PRICES: Dictionary = {
	"red_small": 0,
	"blue_small": 100,
	"green_small": 100,
	"grey_small": 100,
	"red_heavy": 250,
	"blue_heavy": 300,
	"green_heavy": 300,
	"grey_heavy": 300,
}

var DISPLAY_NAMES: Dictionary = {
	"red_small": "Red Light",
	"blue_small": "Blue Light",
	"green_small": "Green Light",
	"grey_small": "Grey Light",
	"red_heavy": "Red Heavy",
	"blue_heavy": "Blue Heavy",
	"green_heavy": "Green Heavy",
	"grey_heavy": "Grey Heavy",
}

# ── Node refs — these match the scene tree nodes ─────────────
@onready var back_button: Button = $UI/BackButton
@onready var credits_label: Label = $UI/CreditsLabel
@onready var info_label: Label = $UI/InfoLabel

# Character slots — each is a Control node in the scene, named by character id.
# Each slot expects these children:
#   - Sprite (any node, just for visuals — you handle it)
#   - Overlay (ColorRect) — darkened when locked, hidden when owned
#   - LockLabel (Label) — shown when locked
#   - PriceLabel (Label) — shows cost / OWNED / EQUIPPED
#   - ActionButton (Button) — BUY / SELECT / SELECTED

const ALL_CHAR_IDS: Array = [
	"red_small", "blue_small", "green_small", "grey_small",
	"red_heavy", "blue_heavy", "green_heavy", "grey_heavy",
]

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	for id in ALL_CHAR_IDS:
		var slot_node: Control = get_node_or_null(id)
		if not slot_node:
			continue
		slot_node.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_node.gui_input.connect(_on_slot_gui_input.bind(id))
		_set_slot_children_mouse_ignore(slot_node)
		var btn: Button = slot_node.get_node("ActionButton")
		btn.pressed.connect(_on_slot_pressed.bind(id))
		var dark_bg := StyleBoxFlat.new()
		dark_bg.bg_color = Color(0.03, 0.03, 0.06, 0.95)
		dark_bg.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", dark_bg)
		var dark_bg_hover := StyleBoxFlat.new()
		dark_bg_hover.bg_color = Color(0.08, 0.08, 0.12, 0.95)
		dark_bg_hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", dark_bg_hover)
		var dark_bg_pressed := StyleBoxFlat.new()
		dark_bg_pressed.bg_color = Color(0.02, 0.02, 0.04, 0.98)
		dark_bg_pressed.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", dark_bg_pressed)
		var dark_bg_disabled := StyleBoxFlat.new()
		dark_bg_disabled.bg_color = Color(0.02, 0.02, 0.05, 0.95)
		dark_bg_disabled.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("disabled", dark_bg_disabled)
	_update_all()


func _set_slot_children_mouse_ignore(root: Control) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_slot_children_mouse_ignore(child as Control)


func _on_slot_gui_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot_node: Control = get_node_or_null(id)
	if not slot_node:
		return
	var btn: Button = slot_node.get_node_or_null("ActionButton")
	if btn and btn.disabled:
		return
	get_viewport().set_input_as_handled()
	_on_slot_pressed(id)

func _update_all() -> void:
	credits_label.text = "Credits: " + str(SaveManager.get_credits())
	var selected := SaveManager.get_selected_character()
	info_label.text = "Selected: " + DISPLAY_NAMES.get(selected, selected)

	for id in ALL_CHAR_IDS:
		var slot_node: Control = get_node_or_null(id)
		if not slot_node:
			continue
		var cost: int = PRICES.get(id, 0)
		var owned := (cost == 0) or SaveManager.has_character(id)
		var is_selected: bool = (selected == id)

		var overlay: ColorRect = slot_node.get_node("Overlay")
		var lock_label: Label = slot_node.get_node("LockLabel")
		var price_label: Label = slot_node.get_node("PriceLabel")
		var btn: Button = slot_node.get_node("ActionButton")

		if owned:
			overlay.visible = false
			lock_label.visible = false
			price_label.visible = false
			if is_selected:
				btn.text = "SELECTED"
				btn.disabled = true
			else:
				btn.text = "SELECT"
				btn.disabled = false
		else:
			overlay.visible = true
			lock_label.visible = true
			price_label.visible = false
			if SaveManager.get_credits() >= cost:
				btn.text = str(cost) + " CR"
				btn.disabled = false
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			else:
				btn.text = str(cost) + " CR"
				btn.disabled = true
				btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.2, 0.2))

func _on_slot_pressed(id: String) -> void:
	var cost: int = PRICES.get(id, 0)
	var owned := (cost == 0) or SaveManager.has_character(id)

	if owned:
		SaveManager.set_selected_character(id)
		AudioManager.play_sfx("ui_click")
	else:
		if SaveManager.spend_credits(cost):
			SaveManager.unlock_character(id)
			SaveManager.set_selected_character(id)
			AudioManager.play_sfx("ui_click")
	_update_all()
	_play_selected_anim(id)

func _play_selected_anim(id: String) -> void:
	var slot_node: Control = get_node_or_null(id)
	if not slot_node:
		return
	var sprite: AnimatedSprite2D = slot_node.get_node_or_null("Sprite")
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation("selected"):
		return
	sprite.play("selected")
	await sprite.animation_finished
	if is_instance_valid(sprite):
		sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_back() -> void:
	SceneTransition.change_scene("res://scenes/menus/main_menu.tscn")
