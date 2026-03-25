extends CanvasLayer

@onready var panel: PanelContainer = $Panel
@onready var resume_button: Button = $Panel/VBoxContainer/ResumeButton
@onready var settings_button: Button = $Panel/VBoxContainer/SettingsButton
@onready var restart_button: Button = $Panel/VBoxContainer/RestartButton
@onready var main_menu_button: Button = $Panel/VBoxContainer/MainMenuButton

# Settings panel
@onready var settings_panel: PanelContainer = $SettingsPanel
@onready var master_slider: HSlider = $SettingsPanel/VBox/MasterRow/MasterSlider
@onready var master_value: Label = $SettingsPanel/VBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $SettingsPanel/VBox/MusicRow/MusicSlider
@onready var music_value: Label = $SettingsPanel/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $SettingsPanel/VBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $SettingsPanel/VBox/SFXRow/SFXValue
@onready var mute_check: CheckButton = $SettingsPanel/VBox/MuteRow/MuteCheck
@onready var settings_back_button: Button = $SettingsPanel/VBox/BackButton

func _ready() -> void:
	resume_button.pressed.connect(_on_resume)
	settings_button.pressed.connect(_on_settings)
	restart_button.pressed.connect(_on_restart)
	main_menu_button.pressed.connect(_on_main_menu)

	# Settings connections
	master_slider.value_changed.connect(_on_master_changed)
	music_slider.value_changed.connect(_on_music_changed)
	sfx_slider.value_changed.connect(_on_sfx_changed)
	mute_check.toggled.connect(_on_mute_toggled)
	settings_back_button.pressed.connect(_on_settings_back)

	visible = false

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
	panel.visible = true
	settings_panel.visible = false
	get_tree().paused = true
	resume_button.grab_focus()

func _on_resume() -> void:
	visible = false
	get_tree().paused = false

func _on_settings() -> void:
	panel.visible = false
	settings_panel.visible = true
	# Load current values
	master_slider.value = SaveManager.get_setting("master_volume", 1.0) * 100.0
	music_slider.value = SaveManager.get_setting("music_volume", 0.8) * 100.0
	sfx_slider.value = SaveManager.get_setting("sfx_volume", 0.8) * 100.0
	mute_check.button_pressed = SaveManager.get_setting("muted", false)
	_update_labels()
	settings_back_button.grab_focus()

func _on_settings_back() -> void:
	settings_panel.visible = false
	panel.visible = true
	settings_button.grab_focus()

func _on_restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

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
