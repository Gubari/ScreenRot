extends CanvasLayer

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)
const HOVER_PREFIX := "> "

@onready var main_panel: VBoxContainer = $MainPanel
@onready var resume_label: Label = $MainPanel/ResumeLabel
@onready var settings_label: Label = $MainPanel/SettingsLabel
@onready var restart_label: Label = $MainPanel/RestartLabel
@onready var main_menu_label: Label = $MainPanel/MainMenuLabel

# Settings panel
@onready var settings_panel: VBoxContainer = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/MasterRow/MasterSlider
@onready var master_value: Label = $SettingsPanel/MasterRow/MasterValue
@onready var music_slider: HSlider = $SettingsPanel/MusicRow/MusicSlider
@onready var music_value: Label = $SettingsPanel/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $SettingsPanel/SFXRow/SFXSlider
@onready var sfx_value: Label = $SettingsPanel/SFXRow/SFXValue
@onready var mute_check: CheckButton = $SettingsPanel/MuteRow/MuteCheck
@onready var settings_back_label: Label = $SettingsPanel/BackLabel

var menu_items: Array[Dictionary] = []

func _ready() -> void:
	menu_items = [
		{"label": resume_label, "text": "RESUME", "action": _on_resume},
		{"label": settings_label, "text": "SETTINGS", "action": _on_settings},
		{"label": restart_label, "text": "RESTART", "action": _on_restart},
		{"label": main_menu_label, "text": "ABANDON RUN", "color": Color.RED, "action": _on_main_menu},
	]

	for item in menu_items:
		item.label.text = item.text
		_setup_interactive_label(item.label)
		item.label.mouse_entered.connect(_on_item_hover.bind(item))
		item.label.mouse_exited.connect(_on_item_unhover.bind(item))
		item.label.gui_input.connect(_on_item_input.bind(item))

	# Settings panel connections
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_check.toggled.connect(_on_mute_toggled)

	# Settings back label
	_setup_interactive_label(settings_back_label)
	settings_back_label.mouse_entered.connect(_on_back_hover)
	settings_back_label.mouse_exited.connect(_on_back_unhover)
	settings_back_label.gui_input.connect(_on_back_input)

	visible = false

func _setup_interactive_label(label: Label) -> void:
	label.mouse_filter = Control.MOUSE_FILTER_STOP
	label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not label.has_theme_color_override("font_color"):
		label.add_theme_color_override("font_color", COLOR_NORMAL)

func _on_item_hover(item: Dictionary) -> void:
	item.label.text = HOVER_PREFIX + item.text
	item.label.add_theme_color_override("font_color", COLOR_HOVER)

func _on_item_unhover(item: Dictionary) -> void:
	item.label.text = item.text
	item.label.add_theme_color_override("font_color", item.get("color", COLOR_NORMAL))

func _on_item_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		Input.action_release("shoot")
		AudioManager.play_sfx("ui_click")
		item.action.call()

func _on_back_hover() -> void:
	settings_back_label.text = HOVER_PREFIX + "BACK"
	settings_back_label.add_theme_color_override("font_color", COLOR_HOVER)

func _on_back_unhover() -> void:
	settings_back_label.text = "BACK"
	settings_back_label.add_theme_color_override("font_color", COLOR_NORMAL)

func _on_back_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		Input.action_release("shoot")
		AudioManager.play_sfx("ui_click")
		_on_settings_back()

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		if visible:
			if settings_panel.visible:
				_on_settings_back()
			else:
				_on_resume()
		else:
			_show_pause()
		get_viewport().set_input_as_handled()

func _show_pause() -> void:
	visible = true
	main_panel.visible = true
	settings_panel.visible = false
	AudioManager.pause_music()
	get_tree().paused = true
	CursorManager.set_menu_cursor()

func _on_resume() -> void:
	visible = false
	get_tree().paused = false
	AudioManager.resume_music()
	CursorManager.set_crosshair()

func _on_settings() -> void:
	main_panel.visible = false
	settings_panel.visible = true
	# Load current values
	master_slider.value = SaveManager.get_setting("master_volume", 1.0) * 100.0
	music_slider.value = SaveManager.get_setting("music_volume", 0.8) * 100.0
	sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8) * 100.0
	mute_check.button_pressed = SaveManager.get_setting("muted", false)
	_update_labels()

func _on_settings_back() -> void:
	settings_panel.visible = false
	main_panel.visible = true

func _on_restart() -> void:
	AudioManager.resume_music()
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/game.tscn")

func _on_main_menu() -> void:
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/menus/main_menu.tscn")

# --- Settings handlers ---

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
