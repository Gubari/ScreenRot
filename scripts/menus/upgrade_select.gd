extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)

const UPGRADE_POOL: Array = [
	# Combat upgrades
	{"id": "rapid_fire", "name": "Rapid Fire", "desc": "Fire rate increased by 25%", "category": "combat"},
	{"id": "heavy_rounds", "name": "Heavy Rounds", "desc": "Bullet damage increased by 1", "category": "combat"},
	{"id": "velocity_boost", "name": "Velocity Boost", "desc": "Move speed increased by 20%", "category": "combat"},
	{"id": "armor_plating", "name": "Armor Plating", "desc": "Max HP & Current HP increased by 5", "category": "combat"},
	{"id": "double_shot", "name": "Double Shot", "desc": "Shoots 2 bullets one after another", "category": "combat"},
	# Debris / Defrag upgrades
	{"id": "lucky_drops", "name": "Lucky Drops", "desc": "Defrag drop chance increased by 10%", "category": "defrag"},
	{"id": "extended_pickup", "name": "Extended Defrag Pickup", "desc": "Defrag stays on the floor for 3 more seconds", "category": "defrag"},
	{"id": "strong_defrag", "name": "Stronger Defrag", "desc": "Defrag clears 15% more debris", "category": "defrag"},
	{"id": "clean_kill", "name": "Clean Kill", "desc": "15% chance to leave no debris on kill", "category": "defrag"},
	# Movement upgrade
	{"id": "quick_dash", "name": "Quick Dash", "desc": "Dash cooldown decreased by 25%", "category": "combat"},
]

const CATEGORY_COLORS: Dictionary = {
	"combat": Color(1.0, 0.3, 0.3),
	"defrag": Color(0.3, 1.0, 0.5),
}

var chosen_upgrades: Array = []
var current_picks: Array = []

@onready var title_label: Label = $ContentBox/Title
@onready var cards: Array[Control] = [
	$ContentBox/CardContainer/Card1,
	$ContentBox/CardContainer/Card2,
	$ContentBox/CardContainer/Card3,
]

func _ready() -> void:
	visible = false
	for i in 3:
		# Each card gets its own shader material instance so we can tint independently
		var card_bg: ColorRect = cards[i].get_node("CardBG")
		card_bg.material = card_bg.material.duplicate()

		var choose_label: Label = cards[i].get_node("VBox/ChooseLabel")
		choose_label.mouse_filter = Control.MOUSE_FILTER_STOP
		choose_label.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		choose_label.add_theme_color_override("font_color", COLOR_NORMAL)
		choose_label.mouse_entered.connect(_on_card_hover.bind(i))
		choose_label.mouse_exited.connect(_on_card_unhover.bind(i))
		choose_label.gui_input.connect(_on_card_input.bind(i))

func _on_card_hover(index: int) -> void:
	var choose_label: Label = cards[index].get_node("VBox/ChooseLabel")
	choose_label.text = "> CHOOSE <"
	choose_label.add_theme_color_override("font_color", COLOR_HOVER)
	var color_bar: ColorRect = cards[index].get_node("VBox/ColorBar")
	color_bar.custom_minimum_size.y = 5
	# Brighten shader border on hover
	var card_bg: ColorRect = cards[index].get_node("CardBG")
	var cat_color: Color = color_bar.color
	card_bg.material.set_shader_parameter("border_color", Color(cat_color.r, cat_color.g, cat_color.b, 0.8))
	card_bg.material.set_shader_parameter("glow_intensity", 0.6)

func _on_card_unhover(index: int) -> void:
	var choose_label: Label = cards[index].get_node("VBox/ChooseLabel")
	choose_label.text = "[ CHOOSE ]"
	choose_label.add_theme_color_override("font_color", COLOR_NORMAL)
	var color_bar: ColorRect = cards[index].get_node("VBox/ColorBar")
	color_bar.custom_minimum_size.y = 3
	# Reset shader to pre-hover state (category color with original alpha)
	var card_bg: ColorRect = cards[index].get_node("CardBG")
	var cat_color: Color = color_bar.color
	card_bg.material.set_shader_parameter("border_color", Color(cat_color.r, cat_color.g, cat_color.b, 0.4))
	card_bg.material.set_shader_parameter("glow_intensity", 0.3)

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		get_viewport().set_input_as_handled()
		Input.action_release("shoot")
		_on_upgrade_picked(index)

func show_upgrades(_wave_number: int) -> void:
	title_label.text = "CHOOSE UPGRADE"

	var available: Array = UPGRADE_POOL.filter(
		func(u): return u.id not in chosen_upgrades
	)
	available.shuffle()
	current_picks = available.slice(0, 3)

	# No upgrades left — skip straight to next wave
	if current_picks.is_empty():
		upgrade_chosen.emit("")
		return

	for i in 3:
		if i < current_picks.size():
			_fill_card(cards[i], current_picks[i])
			cards[i].visible = true
		else:
			cards[i].visible = false

	visible = true
	get_tree().paused = true
	CursorManager.set_menu_cursor()

func _fill_card(card: Control, upgrade: Dictionary) -> void:
	var color: Color = CATEGORY_COLORS.get(upgrade.category, Color.WHITE)
	var vbox: VBoxContainer = card.get_node("VBox")
	vbox.get_node("ColorBar").color = color
	vbox.get_node("Category").text = upgrade.category.to_upper()
	vbox.get_node("Category").add_theme_color_override("font_color", color)
	vbox.get_node("Name").text = upgrade.name
	vbox.get_node("Desc").text = upgrade.desc
	# Tint the bottom bar and shader border with the category color
	vbox.get_node("BottomBar").color = Color(color.r, color.g, color.b, 0.3)
	var card_bg: ColorRect = card.get_node("CardBG")
	card_bg.material.set_shader_parameter("border_color", Color(color.r, color.g, color.b, 0.4))

func _on_upgrade_picked(index: int) -> void:
	var upgrade_id: String = current_picks[index].id
	chosen_upgrades.append(upgrade_id)
	AudioManager.play_sfx("ui_click")
	visible = false
	get_tree().paused = false
	CursorManager.set_crosshair()
	upgrade_chosen.emit(upgrade_id)
