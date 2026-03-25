extends CanvasLayer

@onready var score_value: Label = $Panel/ScoreValue
@onready var credits_value: Label = $Panel/CreditsValue
@onready var retry_button: Button = $Panel/RetryButton
@onready var quit_button: Button = $Panel/QuitButton

func _ready() -> void:
	retry_button.pressed.connect(_on_retry)
	quit_button.pressed.connect(_on_quit)
	visible = false

func show_game_over(score: int, credits: int) -> void:
	score_value.text = str(score)
	credits_value.text = str(credits)
	visible = true
	get_tree().paused = true

func _on_retry() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func _on_quit() -> void:
	get_tree().quit()
