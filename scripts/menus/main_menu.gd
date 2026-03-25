extends Control

@onready var start_button: Button = $VBoxContainer/StartButton
@onready var shop_button: Button = $VBoxContainer/ShopButton
@onready var settings_button: Button = $VBoxContainer/SettingsButton
@onready var quit_button: Button = $VBoxContainer/QuitButton
@onready var stats_label: Label = $StatsLabel

func _ready() -> void:
	start_button.pressed.connect(_on_start)
	shop_button.pressed.connect(_on_shop)
	settings_button.pressed.connect(_on_settings)
	quit_button.pressed.connect(_on_quit)
	start_button.grab_focus()
	_update_stats()
	AudioManager.play_music("menu")

func _update_stats() -> void:
	stats_label.text = "Credits: " + str(SaveManager.get_credits()) + "  |  High Score: " + str(SaveManager.get_high_score())

func _on_start() -> void:
	get_tree().change_scene_to_file("res://scenes/game.tscn")

func _on_shop() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/shop.tscn")

func _on_settings() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/settings.tscn")

func _on_quit() -> void:
	get_tree().quit()
