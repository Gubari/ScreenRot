extends CanvasLayer

signal tutorial_finished

@onready var content_label: Label = $Panel/VBox/ContentLabel
@onready var page_sprite: AnimatedSprite2D = $PageSprite
@onready var page_sprite_2: AnimatedSprite2D = $PageSprite2
@onready var prev_button: Button = $Panel/VBox/NavRow/PrevButton
@onready var next_button: Button = $Panel/VBox/NavRow/NextButton
@onready var page_indicator: Label = $Panel/VBox/NavRow/PageIndicator
@onready var close_button: Button = $Panel/VBox/TopRow/CloseButton

var current_page: int = 0
var _pause_menu: CanvasLayer = null
var pages: Array[String] = [
	"Welcome to the station, Pilot\nYou are our only hope\nThe enemy that destroyed our homeworld\nis already here. Take care of them",
	"[MOVEMENT & DASH]\nMove with W A S D\nSHIFT to dash\nUse it to dodge, reposition, escape\nDash has a cooldown. Use it wisely",
	"[COMBAT]\nAim with MOUSE\nLMB to shoot",
	"[DEBRIS]\nDead enemies leave DEBRIS on screen\nMore debris means a higher\nscore/credit multiplier\nBut debris blocks your view. Stay sharp\n",
	"[DEFRAG]\nCollect DEFRAG pickups\nUse them with SPACE to clear debirs",
	"[FAREWELL]\nHope you are ready\n I wish you luck"
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

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_close_tutorial()

func _update_page() -> void:
	content_label.text = pages[current_page]
	page_indicator.text = str(current_page + 1) + "/" + str(pages.size())
	page_sprite.visible = current_page == 4
	page_sprite_2.visible = current_page == 4
	if current_page == 4:
		page_sprite.play("default")
		page_sprite_2.play("default")
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
