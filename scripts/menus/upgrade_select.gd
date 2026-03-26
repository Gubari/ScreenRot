extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

const COLOR_NORMAL := Color(0.45, 0.45, 0.5)
const COLOR_HOVER := Color(0.85, 0.9, 1.0)

const UPGRADE_POOL: Array = [
	{"id": "fire_rate_up", "name": "Fire Rate+", "desc": "Pucanje 20% brze", "category": "offense"},
	{"id": "spread_shot", "name": "Spread Shot", "desc": "3 metka u lepezi", "category": "offense"},
	{"id": "piercing", "name": "Piercing Rounds", "desc": "Meci prolaze kroz 2 neprijatelja", "category": "offense"},
	{"id": "ricochet", "name": "Ricochet", "desc": "Meci se odbijaju od ivica", "category": "offense"},
	{"id": "explosive", "name": "Explosive Rounds", "desc": "Mali AoE eksplozija na kontakt", "category": "offense"},
	{"id": "overcharge", "name": "Overcharge", "desc": "+50% damage na x3+ multiplikatoru", "category": "offense"},
	{"id": "shield", "name": "Shield", "desc": "Apsorbuje 1 hit po wave-u", "category": "defense"},
	{"id": "speed_boost", "name": "Speed Boost", "desc": "+15% brzina kretanja", "category": "defense"},
	{"id": "hp_regen", "name": "HP Regen", "desc": "+1 HP na pocetku svakog wave-a", "category": "defense"},
	{"id": "ad_block", "name": "Ad Block", "desc": "Auto-zatvara 1 pop-up svakih 8s", "category": "ui"},
	{"id": "dark_mode", "name": "Dark Mode", "desc": "Debris postaje providniji na 3s", "category": "ui"},
	{"id": "defrag_plus", "name": "Defrag+", "desc": "Defrag cooldown -3s", "category": "ui"},
	{"id": "auto_close", "name": "Auto-Close", "desc": "UI elementi nestaju 2s brze", "category": "ui"},
	{"id": "spam_filter", "name": "Spam Filter", "desc": "Cookie banneri 50% redje", "category": "ui"},
	{"id": "premium", "name": "Premium Account", "desc": "Svi UI elementi 30% manji", "category": "ui"},
]

const CATEGORY_COLORS: Dictionary = {
	"offense": Color(1.0, 0.3, 0.3),
	"defense": Color(0.3, 0.7, 1.0),
	"ui": Color(0.3, 1.0, 0.5),
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
	# Reset shader to default
	var card_bg: ColorRect = cards[index].get_node("CardBG")
	card_bg.material.set_shader_parameter("border_color", Color(0.3, 0.3, 0.4, 0.6))
	card_bg.material.set_shader_parameter("glow_intensity", 0.3)

func _on_card_input(event: InputEvent, index: int) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		_on_upgrade_picked(index)

func show_upgrades(wave_number: int) -> void:
	title_label.text = "WAVE %d CLEARED - CHOOSE UPGRADE" % wave_number

	var available: Array = UPGRADE_POOL.filter(
		func(u): return u.id not in chosen_upgrades
	)
	available.shuffle()
	current_picks = available.slice(0, 3)

	for i in 3:
		_fill_card(cards[i], current_picks[i])

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
	AudioManager.play_sfx("level_up")
	visible = false
	get_tree().paused = false
	CursorManager.set_crosshair()
	upgrade_chosen.emit(upgrade_id)
