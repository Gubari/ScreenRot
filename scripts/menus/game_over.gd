extends CanvasLayer

@onready var title_label: Label = $Panel/Title
@onready var subtitle_label: Label = $Panel/Subtitle
@onready var score_value: Label = $Panel/ScoreValue
@onready var credits_value: Label = $Panel/CreditsValue
@onready var high_score_value: Label = $Panel/HighScoreValue
@onready var total_credits_value: Label = $Panel/TotalCreditsValue
@onready var retry_button: Button = $Panel/RetryButton
@onready var main_menu_button: Button = $Panel/MainMenuButton
@onready var quit_button: Button = $Panel/QuitButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry)
	main_menu_button.pressed.connect(_on_main_menu)
	quit_button.pressed.connect(_on_quit)
	visible = false

func show_game_over(score: int, credits_earned: int, title: String = "GAME OVER", subtitle: String = "") -> void:
	title_label.text = title
	if subtitle != "":
		subtitle_label.text = subtitle
		subtitle_label.visible = true
	else:
		subtitle_label.visible = false
	score_value.text = str(score)
	credits_value.text = "+" + str(credits_earned)
	high_score_value.text = str(SaveManager.get_high_score())
	total_credits_value.text = str(SaveManager.get_credits())
	visible = true
	get_tree().paused = true

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_main_menu() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
