extends Control

@onready var classic_label: Label = $MenuContainer/ClassicLabel
@onready var challenge_label: Label = $MenuContainer/EndlessLabel
@onready var settings_label: Label = $MenuContainer/SettingsLabel
@onready var character_label: Label = $MenuContainer/CharacterLabel
@onready var quit_label: Label = $MenuContainer/QuitLabel
@onready var stats_label: Label = $StatsLabel
@onready var lock_bubble: Control = $LockBubble

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)
const COLOR_LOCKED := Color(0.25, 0.25, 0.3)
const HOVER_PREFIX := "> "

var menu_items: Array[Dictionary] = []
var _challenge_locked: bool = false
var _web_audio_prompt: ColorRect = null

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

	lock_bubble.visible = false
	if _challenge_locked:
		challenge_label.text = "ENDLESS MODE"
		challenge_label.add_theme_color_override("font_color", COLOR_LOCKED)
		challenge_label.mouse_default_cursor_shape = Control.CURSOR_ARROW

	_update_stats()
	SaveManager.credits_changed.connect(_on_credits_changed)
	_update_character_label()
	CursorManager.set_menu_cursor()
	AudioManager.play_music("menu")
	if OS.has_feature("web") and not AudioManager.is_web_audio_unlocked():
		_setup_web_audio_prompt()

func _setup_web_audio_prompt() -> void:
	_web_audio_prompt = ColorRect.new()
	_web_audio_prompt.name = "WebAudioPrompt"
	_web_audio_prompt.mouse_filter = Control.MOUSE_FILTER_STOP
	_web_audio_prompt.color = Color(0.02, 0.03, 0.07, 0.86)
	_web_audio_prompt.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web_audio_prompt.z_index = 100
	add_child(_web_audio_prompt)

	var center := CenterContainer.new()
	center.name = "Center"
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_web_audio_prompt.add_child(center)

	var message := Label.new()
	message.name = "Message"
	message.mouse_filter = Control.MOUSE_FILTER_IGNORE
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	message.theme_override_font_sizes.font_size = 56
	message.theme_override_colors.font_color = Color(0.92, 0.96, 1.0, 1.0)
	message.text = "CLICK TO START"
	center.add_child(message)

func _is_unlock_event(event: InputEvent) -> bool:
	return event is InputEventMouseButton \
			and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT

func _input(event: InputEvent) -> void:
	if _web_audio_prompt and _is_unlock_event(event):
		get_viewport().set_input_as_handled()
		_dismiss_web_audio_prompt()

func _dismiss_web_audio_prompt() -> void:
	if not _web_audio_prompt:
		return
	AudioManager.notify_user_gesture()
	AudioManager.play_music("menu")
	_web_audio_prompt.queue_free()
	_web_audio_prompt = null

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
			get_viewport().set_input_as_handled()
			_show_lock_bubble()
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
	SceneTransition.change_scene("res://scenes/game.tscn")

func _on_challenge() -> void:
	GameMode.current_mode = GameMode.Mode.CHALLENGE
	SceneTransition.change_scene("res://scenes/game.tscn")

func _on_settings() -> void:
	SceneTransition.change_scene("res://scenes/menus/settings.tscn")

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
	SceneTransition.change_scene("res://scenes/menus/shop.tscn")

var _lock_bubble_tween: Tween = null

func _show_lock_bubble() -> void:
	if _lock_bubble_tween:
		_lock_bubble_tween.kill()
	lock_bubble.modulate.a = 1.0
	lock_bubble.visible = true
	_lock_bubble_tween = create_tween()
	_lock_bubble_tween.tween_interval(3.0)
	_lock_bubble_tween.tween_property(lock_bubble, "modulate:a", 0.0, 0.5)
	_lock_bubble_tween.tween_callback(func(): lock_bubble.visible = false)
