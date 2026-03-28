extends Control

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)
const HOVER_PREFIX := "> "

@onready var master_slider: HSlider = $ContentBox/MasterRow/MasterSlider
@onready var master_value: Label = $ContentBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $ContentBox/MusicRow/MusicSlider
@onready var music_value: Label = $ContentBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $ContentBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $ContentBox/SFXRow/SFXValue
@onready var mute_check: CheckButton = $ContentBox/MuteRow/MuteCheck
@onready var fullscreen_check: CheckButton = $ContentBox/FullscreenRow/FullscreenCheck
@onready var back_label: Label = $BackLabel

const BINDABLE_ACTIONS: Array = [
	{"action": "move_up",    "button_path": "ContentBox/BindRow_move_up/BindButton_move_up"},
	{"action": "move_down",  "button_path": "ContentBox/BindRow_move_down/BindButton_move_down"},
	{"action": "move_left",  "button_path": "ContentBox/BindRow_move_left/BindButton_move_left"},
	{"action": "move_right", "button_path": "ContentBox/BindRow_move_right/BindButton_move_right"},
	{"action": "dash",       "button_path": "ContentBox/BindRow_dash/BindButton_dash"},
	{"action": "defrag",     "button_path": "ContentBox/BindRow_defrag/BindButton_defrag"},
	{"action": "shoot",      "button_path": "ContentBox/BindRow_shoot/BindButton_shoot"},
]

var _listening_action: String = ""
var _listening_button: Button = null

func _ready() -> void:
	master_slider.value = SaveManager.get_setting("master_volume", 0.2) * 100.0
	music_slider.value = SaveManager.get_setting("music_volume", 0.8) * 100.0
	sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8) * 100.0
	mute_check.button_pressed = SaveManager.get_setting("muted", false)
	fullscreen_check.button_pressed = SaveManager.get_setting("fullscreen", false)

	_update_labels()
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	fullscreen_check.toggled.connect(_on_fullscreen_toggled)

	for entry in BINDABLE_ACTIONS:
		var btn := get_node(entry.button_path) as Button
		btn.pressed.connect(_on_bind_button_pressed.bind(entry.action, btn))
		_update_bind_button(entry.action, btn)

	back_label.mouse_filter = Control.MOUSE_FILTER_STOP
	back_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	back_label.add_theme_color_override("font_color", COLOR_NORMAL)
	back_label.mouse_entered.connect(_on_back_hover)
	back_label.mouse_exited.connect(_on_back_unhover)
	back_label.gui_input.connect(_on_back_input)

func _on_back_hover() -> void:
	back_label.text = HOVER_PREFIX + "BACK"
	back_label.add_theme_color_override("font_color", COLOR_HOVER)

func _on_back_unhover() -> void:
	back_label.text = "BACK"
	back_label.add_theme_color_override("font_color", COLOR_NORMAL)

func _input(event: InputEvent) -> void:
	if _listening_action != "":
		if event is InputEventKey and event.pressed and not event.echo:
			get_viewport().set_input_as_handled()
			if event.physical_keycode == KEY_ESCAPE:
				_listening_button.text = _get_action_display_name(_listening_action)
				_listening_button.release_focus()
				_listening_action = ""
				_listening_button = null
			else:
				InputMap.action_erase_events(_listening_action)
				var ev := InputEventKey.new()
				ev.physical_keycode = event.physical_keycode
				InputMap.action_add_event(_listening_action, ev)
				SaveManager.save_keybinding(_listening_action, {"type": "key", "code": event.physical_keycode})
				_listening_button.text = OS.get_keycode_string(event.physical_keycode)
				_listening_button.release_focus()
				_listening_action = ""
				_listening_button = null
		elif event is InputEventMouseButton and event.pressed:
			get_viewport().set_input_as_handled()
			InputMap.action_erase_events(_listening_action)
			var ev := InputEventMouseButton.new()
			ev.button_index = event.button_index
			InputMap.action_add_event(_listening_action, ev)
			SaveManager.save_keybinding(_listening_action, {"type": "mouse", "code": event.button_index})
			_listening_button.text = _mouse_button_name(event.button_index)
			_listening_button.release_focus()
			_listening_action = ""
			_listening_button = null
		return
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_back()

func _on_back_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_go_back()

func _go_back() -> void:
	SceneTransition.change_scene("res://scenes/menus/main_menu.tscn")

func _update_labels() -> void:
	master_value.text = str(int(master_slider.value)) + "%"
	music_value.text = str(int(music_slider.value)) + "%"
	sfx_value.text = str(int(sfx_slider.value)) + "%"

func _on_master_changed(value: float) -> void:
	SaveManager.set_setting("master_volume", value / 100.0)
	_update_labels()

func _on_music_changed(value: float) -> void:
	SaveManager.set_setting("music_volume", value / 100.0)
	_update_labels()

func _on_sfx_changed(value: float) -> void:
	SaveManager.set_setting("sfx_volume", value / 100.0)
	_update_labels()

func _on_mute_toggled(pressed: bool) -> void:
	SaveManager.set_setting("muted", pressed)

func _on_fullscreen_toggled(pressed: bool) -> void:
	SaveManager.set_setting("fullscreen", pressed)
	SaveManager.apply_display_settings()

func _on_bind_button_pressed(action: String, btn: Button) -> void:
	if _listening_action != "":
		_listening_button.text = _get_action_display_name(_listening_action)
	_listening_action = action
	_listening_button = btn
	btn.text = "..."

func _update_bind_button(action: String, btn: Button) -> void:
	btn.text = _get_action_display_name(action)

func _get_action_display_name(action: String) -> String:
	for ev in InputMap.action_get_events(action):
		if ev is InputEventKey:
			return OS.get_keycode_string(ev.physical_keycode)
		if ev is InputEventMouseButton:
			return _mouse_button_name(ev.button_index)
	return "?"

func _mouse_button_name(index: int) -> String:
	match index:
		MOUSE_BUTTON_LEFT:   return "LMB"
		MOUSE_BUTTON_RIGHT:  return "RMB"
		MOUSE_BUTTON_MIDDLE: return "MMB"
		_: return "Mouse " + str(index)
