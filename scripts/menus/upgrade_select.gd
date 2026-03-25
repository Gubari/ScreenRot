extends CanvasLayer

signal upgrade_chosen(upgrade_id: String)

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
