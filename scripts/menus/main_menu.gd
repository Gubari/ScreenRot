extends Control

@onready var classic_label: Label = $MenuContainer/ClassicLabel
@onready var challenge_label: Label = $MenuContainer/EndlessLabel
@onready var settings_label: Label = $MenuContainer/SettingsLabel
@onready var character_label: Label = $MenuContainer/CharacterLabel
@onready var quit_label: Label = $MenuContainer/QuitLabel
@onready var stats_label: Label = $StatsLabel

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)
const COLOR_LOCKED := Color(0.25, 0.25, 0.3)
const HOVER_PREFIX := "> "

var menu_items: Array[Dictionary] = []
var _challenge_locked: bool = false

func _ready() -> void:
	_challenge_locked = not SaveManager.is_challenge_unlocked()

	menu_items = [
		{"label": classic_label, "text": "CLASSIC MODE", "action": _on_classic},
		{"label": challenge_label, "text": "ENDLESS MODE", "action": _on_challenge},
		{"label": settings_label, "text": "SETTINGS", "action": _on_settings},
		{"label": character_label, "text": "CHARACTER", "action": _on_character_shop},
		{"label": quit_label, "text": "QUIT", "action": _on_quit},
	]

	for item in menu_items:
		var label: Label = item.label
		label.mouse_filter = Control.MOUSE_FILTER_STOP
		label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		label.add_theme_color_override("font_color", COLOR_NORMAL)
		label.mouse_entered.connect(_on_item_hover.bind(item))
		label.mouse_exited.connect(_on_item_unhover.bind(item))
		label.gui_input.connect(_on_item_input.bind(item))

	if _challenge_locked:
		challenge_label.text = "CHALLENGE MODE [LOCKED]"
		challenge_label.add_theme_color_override("font_color", COLOR_LOCKED)
		challenge_label.mouse_default_cursor_shape = Control.CURSOR_ARROW

	_update_stats()
	SaveManager.credits_changed.connect(_on_credits_changed)
	_update_character_label()
	CursorManager.set_menu_cursor()
	AudioManager.play_music("menu")

func _on_item_hover(item: Dictionary) -> void:
	if item.label == challenge_label and _challenge_locked:
		return
	if item.label == character_label:
		_update_character_label()
		character_label.text = HOVER_PREFIX + character_label.text
	else:
		item.label.text = HOVER_PREFIX + item.text
	item.label.add_theme_color_override("font_color", COLOR_HOVER)

func _on_item_unhover(item: Dictionary) -> void:
	if item.label == challenge_label and _challenge_locked:
		return
	if item.label == character_label:
		_update_character_label()
	else:
		item.label.text = item.text
	item.label.add_theme_color_override("font_color", COLOR_NORMAL)

func _on_item_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		if item.label == challenge_label and _challenge_locked:
			return
		get_viewport().set_input_as_handled()
		Input.action_release("shoot")
		AudioManager.play_sfx("ui_click")
		item.action.call()

func _update_stats() -> void:
	stats_label.text = "Credits: %d  |  High Score: %d" % [SaveManager.get_credits(), SaveManager.get_high_score()]

func _on_credits_changed(_amount: int) -> void:
	_update_stats()

func _on_classic() -> void:
	GameMode.current_mode = GameMode.Mode.CLASSIC
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_challenge() -> void:
	GameMode.current_mode = GameMode.Mode.CHALLENGE
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _on_quit() -> void:
	get_tree().quit()

const CHAR_DISPLAY_NAMES: Dictionary = {
	"red_small": "RED LIGHT",
	"blue_small": "BLUE LIGHT",
	"green_small": "GREEN LIGHT",
	"grey_small": "GREY LIGHT",
	"red_heavy": "RED HEAVY",
	"blue_heavy": "BLUE HEAVY",
	"green_heavy": "GREEN HEAVY",
	"grey_heavy": "GREY HEAVY",
}

func _display_name(char_id: String) -> String:
	return CHAR_DISPLAY_NAMES.get(char_id, char_id.to_upper())

func _update_character_label() -> void:
	var sel := SaveManager.get_selected_character()
	if sel != "red_small" and not SaveManager.has_character(sel):
		sel = "red_small"
		SaveManager.set_selected_character(sel)
	character_label.text = "CHARACTERS"

func _on_character_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/shop.tscn")
