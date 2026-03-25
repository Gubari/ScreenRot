extends Control

const SHOP_ITEMS: Array = [
	{"id": "hp_plus_1", "name": "HP +1", "desc": "Start with 6 HP instead of 5", "cost": 30},
	{"id": "quick_boot", "name": "Quick Boot", "desc": "Wave 1 has 10% fewer enemies", "cost": 20},
	{"id": "defrag_cd_1", "name": "Defrag -1s", "desc": "Defrag cooldown starts at 11s", "cost": 40},
	{"id": "start_speed", "name": "Speed +5%", "desc": "Slightly faster movement from the start", "cost": 25},
	{"id": "hp_plus_2", "name": "HP +2", "desc": "Start with 7 HP", "cost": 80},
	{"id": "defrag_cd_2", "name": "Defrag -2s", "desc": "Defrag cooldown at 10s", "cost": 90},
	{"id": "lucky_rolls", "name": "Lucky Rolls", "desc": "Level-up offers 4 choices instead of 3", "cost": 100},
	{"id": "hp_plus_3", "name": "HP +3", "desc": "Start with 8 HP", "cost": 200},
	{"id": "double_credits", "name": "Double Credits", "desc": "Earn 2x credits permanently", "cost": 300},
]

@onready var credits_label: Label = $TopBar/CreditsLabel
@onready var item_container: VBoxContainer = $ScrollContainer/ItemContainer
@onready var back_button: Button = $TopBar/BackButton

var buy_buttons: Array[Button] = []

func _ready() -> void:
	back_button.pressed.connect(_on_back)
	_populate_shop()
	_update_display()

func _populate_shop() -> void:
	for child in item_container.get_children():
		child.queue_free()
	buy_buttons.clear()

	for item in SHOP_ITEMS:
		var row := _create_item_row(item)
		item_container.add_child(row)

func _create_item_row(item: Dictionary) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)

	# Name + Desc
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.name
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.desc
	desc_label.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	info.add_child(desc_label)

	row.add_child(info)

	# Cost label
	var cost_label := Label.new()
	cost_label.text = str(item.cost) + " CR"
	cost_label.custom_minimum_size = Vector2(80, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	row.add_child(cost_label)

	# Buy button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(_on_buy.bind(item.id))
	buy_buttons.append(btn)
	row.add_child(btn)

	# Separator
	var sep := HSeparator.new()
	sep.add_theme_constant_override("separation", 4)

	var wrapper := VBoxContainer.new()
	wrapper.add_child(row)
	wrapper.add_child(sep)

	# Return the wrapper so separator is included
	# Actually HBoxContainer is expected, let me restructure
	# Just return row, add separator separately
	return row

func _update_display() -> void:
	credits_label.text = "Credits: " + str(SaveManager.get_credits())

	for i in SHOP_ITEMS.size():
		var item: Dictionary = SHOP_ITEMS[i]
		var btn: Button = buy_buttons[i]

		if SaveManager.has_upgrade(item.id):
			btn.text = "OWNED"
			btn.disabled = true
		elif SaveManager.get_credits() < item.cost:
			btn.text = str(item.cost) + " CR"
			btn.disabled = true
		else:
			btn.text = "BUY"
			btn.disabled = false

func _on_buy(item_id: String) -> void:
	for item in SHOP_ITEMS:
		if item.id == item_id:
			if SaveManager.spend_credits(item.cost):
				SaveManager.purchase_upgrade(item_id)
				_update_display()
			break

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
