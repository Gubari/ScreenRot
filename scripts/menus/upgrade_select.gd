extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

const UPGRADE_POOL: Array = [
	# Combat upgrades
	{"id": "rapid_fire", "name": "Rapid Fire", "desc": "Fire rate +25%", "category": "combat"},
	{"id": "heavy_rounds", "name": "Heavy Rounds", "desc": "Bullet damage +1", "category": "combat"},
	{"id": "velocity_boost", "name": "Velocity Boost", "desc": "Move speed +20%", "category": "combat"},
	{"id": "armor_plating", "name": "Armor Plating", "desc": "Max HP +1 i odmah heal", "category": "combat"},
	{"id": "scatter_shot", "name": "Scatter Shot", "desc": "+2 metka pod uglom", "category": "combat"},
	# Debris / Defrag upgrades
	{"id": "lucky_drops", "name": "Lucky Drops", "desc": "Defrag drop sansa +10%", "category": "defrag"},
	{"id": "extended_pickup", "name": "Extended Pickup", "desc": "Pickup traje 8s umesto 5s", "category": "defrag"},
	{"id": "strong_defrag", "name": "Strong Defrag", "desc": "Pickup cisti 50% umesto 35%", "category": "defrag"},
	{"id": "clean_kill", "name": "Clean Kill", "desc": "15% sanse da kill ne ostavi debris", "category": "defrag"},
	# Movement upgrade
	{"id": "quick_dash", "name": "Quick Dash", "desc": "Dash cooldown -25%", "category": "combat"},
]

const CATEGORY_COLORS: Dictionary = {
	"combat": Color(1.0, 0.3, 0.3),
	"defrag": Color(0.3, 1.0, 0.5),
}

var chosen_upgrades: Array = []
var current_picks: Array = []

@onready var title_label: Label = $Panel/VBoxContainer/Title
@onready var cards: Array[PanelContainer] = [
	$Panel/VBoxContainer/CardContainer/Card1,
	$Panel/VBoxContainer/CardContainer/Card2,
	$Panel/VBoxContainer/CardContainer/Card3,
]

func _ready() -> void:
	visible = false
	for i in 3:
		var btn: Button = cards[i].get_node("VBox/ChooseButton")
		btn.pressed.connect(_on_upgrade_picked.bind(i))

func show_upgrades(wave_number: int) -> void:
	title_label.text = "WAVE " + str(wave_number) + " CLEARED - CHOOSE UPGRADE"

	var available: Array = UPGRADE_POOL.filter(
		func(u): return u.id not in chosen_upgrades
	)
	available.shuffle()
	current_picks = available.slice(0, 3)

	for i in 3:
		_fill_card(cards[i], current_picks[i])

	visible = true
	get_tree().paused = true

func _fill_card(card: PanelContainer, upgrade: Dictionary) -> void:
	var color: Color = CATEGORY_COLORS.get(upgrade.category, Color.WHITE)
	card.get_node("VBox/ColorBar").color = color
	card.get_node("VBox/Category").text = upgrade.category.to_upper()
	card.get_node("VBox/Category").add_theme_color_override("font_color", color)
	card.get_node("VBox/Name").text = upgrade.name
	card.get_node("VBox/Desc").text = upgrade.desc

func _on_upgrade_picked(index: int) -> void:
	var upgrade_id: String = current_picks[index].id
	chosen_upgrades.append(upgrade_id)
	AudioManager.play_sfx("level_up")
	visible = false
	get_tree().paused = false
	upgrade_chosen.emit(upgrade_id)
