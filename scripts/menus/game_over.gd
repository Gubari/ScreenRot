extends CanvasLayer

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)
const HOVER_PREFIX := "> "

@onready var title_label: Label = $ContentBox/Title
@onready var subtitle_label: Label = $ContentBox/Subtitle
@onready var score_value: Label = $ContentBox/ScoreValue
@onready var credits_value: Label = $ContentBox/StatsRow/CreditsBox/CreditsValue
@onready var high_score_value: Label = $ContentBox/StatsRow/HighScoreBox/HighScoreValue
@onready var total_credits_value: Label = $ContentBox/StatsRow/TotalCreditsBox/TotalCreditsValue
@onready var retry_label: Label = $ContentBox/MenuItems/RetryLabel
@onready var main_menu_label: Label = $ContentBox/MenuItems/MainMenuLabel
@onready var quit_label: Label = $ContentBox/MenuItems/QuitLabel

var menu_items: Array[Dictionary] = []

func _ready() -> void:
	menu_items = [
		{"label": retry_label, "text": "TRY AGAIN", "action": _on_retry},
		{"label": main_menu_label, "text": "MAIN MENU", "action": _on_main_menu},
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

	visible = false

func _on_item_hover(item: Dictionary) -> void:
	item.label.text = HOVER_PREFIX + item.text
	item.label.add_theme_color_override("font_color", COLOR_HOVER)

func _on_item_unhover(item: Dictionary) -> void:
	item.label.text = item.text
	item.label.add_theme_color_override("font_color", COLOR_NORMAL)

func _on_item_input(event: InputEvent, item: Dictionary) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		Input.action_release("shoot")
		AudioManager.play_sfx("ui_click")
		item.action.call()

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
	CursorManager.set_menu_cursor()

func _on_retry() -> void:
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/game.tscn")

func _on_main_menu() -> void:
	get_tree().paused = false
	SceneTransition.change_scene("res://scenes/menus/main_menu.tscn")

func _on_quit() -> void:
	get_tree().quit()
