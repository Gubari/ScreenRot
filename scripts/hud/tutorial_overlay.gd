extends CanvasLayer

signal tutorial_finished

@onready var content_label: Label = $Panel/VBox/ContentLabel
@onready var prev_button: Button = $Panel/VBox/NavRow/PrevButton
@onready var next_button: Button = $Panel/VBox/NavRow/NextButton
@onready var page_indicator: Label = $Panel/VBox/NavRow/PageIndicator
@onready var close_button: Button = $Panel/VBox/TopRow/CloseButton

var current_page: int = 0
var _pause_menu: CanvasLayer = null
var pages: Array[String] = [
	"Welcome to the simulation, Pilot.\nWe are testing clone model 417 aka BIOTYPE,\nto see if it can stand up against\nthe real enemy on our homeworld.",
	"[MOVEMENT & DASH]\nUse W A S D to move around.\nPress SHIFT to dash - it makes you\ninvulnerable for a brief moment.\nDash has a cooldown, use it wisely.",
	"[COMBAT & DEBRIS]\nAim with your MOUSE and click LMB to shoot.\nKilling enemies leaves debris on screen.\nMore debris = higher score multiplier,\nbut too much makes it hard to see!\nEnemies drop defrag pickups - collect them\nto clear the screen.",
]

func _ready() -> void:
	layer = 120
	process_mode = Node.PROCESS_MODE_ALWAYS
	close_button.pressed.connect(_close_tutorial)
	prev_button.pressed.connect(_on_prev)
	next_button.pressed.connect(_on_next)
	_update_page()
	_pause_menu = get_tree().current_scene.find_child("PauseMenu", false, false)
	if _pause_menu:
		_pause_menu.process_mode = Node.PROCESS_MODE_DISABLED
	get_tree().paused = true

func _update_page() -> void:
	content_label.text = pages[current_page]
	page_indicator.text = str(current_page + 1) + "/" + str(pages.size())
	prev_button.disabled = current_page == 0
	prev_button.modulate.a = 1.0 if current_page > 0 else 0.3
	if current_page >= pages.size() - 1:
		next_button.text = "START >"
	else:
		next_button.text = ">"

func _on_next() -> void:
	if current_page < pages.size() - 1:
		current_page += 1
		_update_page()
	else:
		_close_tutorial()

func _on_prev() -> void:
	if current_page > 0:
		current_page -= 1
		_update_page()

func _close_tutorial() -> void:
	if _pause_menu:
		_pause_menu.process_mode = Node.PROCESS_MODE_ALWAYS
	SaveManager.set_setting("tutorial_seen", true)
	get_tree().paused = false
	tutorial_finished.emit()
	queue_free()
