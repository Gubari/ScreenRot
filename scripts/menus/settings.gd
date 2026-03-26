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

func _ready() -> void:
	master_slider.value = SaveManager.get_setting("master_volume", 1.0) * 100.0
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

	# Interactive back label
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
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_go_back()

func _on_back_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_go_back()

func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

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
