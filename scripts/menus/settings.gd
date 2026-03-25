extends Control

@onready var master_slider: HSlider = $Panel/VBox/MasterRow/MasterSlider
@onready var master_value: Label = $Panel/VBox/MasterRow/MasterValue
@onready var music_slider: HSlider = $Panel/VBox/MusicRow/MusicSlider
@onready var music_value: Label = $Panel/VBox/MusicRow/MusicValue
@onready var sfx_slider: HSlider = $Panel/VBox/SFXRow/SFXSlider
@onready var sfx_value: Label = $Panel/VBox/SFXRow/SFXValue
@onready var mute_check: CheckButton = $Panel/VBox/MuteRow/MuteCheck
@onready var fullscreen_check: CheckButton = $Panel/VBox/FullscreenRow/FullscreenCheck
@onready var back_button: Button = $TopBar/BackButton

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
	back_button.pressed.connect(_on_back)

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

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
