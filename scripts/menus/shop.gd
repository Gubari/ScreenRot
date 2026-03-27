extends Control

const SHOP_ITEMS: Array = [
	{"id": "char_red_small", "name": "Character: Small", "desc": "Default character (free).", "cost": 0},
	{"id": "char_red_heavy", "name": "New Character: Heavy", "desc": "Unlock the heavy unit (playable).", "cost": 250},
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

func _create_item_row(item: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# Name + Desc
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	var name_label := Label.new()
	name_label.text = item.name
	name_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	info.add_child(name_label)

	var desc_label := Label.new()
	desc_label.text = item.desc
	desc_label.add_theme_color_override("font_color", Color(0.65, 0.7, 0.75))
	info.add_child(desc_label)

	row.add_child(info)

	# Cost label
	var cost_label := Label.new()
	cost_label.text = str(item.cost) + " CR"
	cost_label.custom_minimum_size = Vector2(80, 0)
	cost_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	cost_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cost_label.add_theme_color_override("font_color", Color(0.85, 0.9, 1.0))
	row.add_child(cost_label)

	# Buy button
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(120, 36)
	btn.pressed.connect(_on_buy.bind(item.id))
	buy_buttons.append(btn)
	row.add_child(btn)

	var sep := HSeparator.new()
	sep.modulate = Color(0.2, 0.22, 0.28)

	var wrapper := VBoxContainer.new()
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(row)
	wrapper.add_child(sep)
	return wrapper

func _update_display() -> void:
	credits_label.text = "Credits: " + str(SaveManager.get_credits())
	var selected_char := SaveManager.get_selected_character()

	for i in SHOP_ITEMS.size():
		var item: Dictionary = SHOP_ITEMS[i]
		var btn: Button = buy_buttons[i]

		var char_id := "red_small" if item.id == "char_red_small" else "red_heavy"
		var owned_char := true if char_id == "red_small" else SaveManager.has_character("red_heavy")

		if owned_char:
			if selected_char == char_id:
				btn.text = "SELECTED"
				btn.disabled = true
			else:
				btn.text = "SELECT"
				btn.disabled = false
		else:
			if SaveManager.get_credits() < item.cost:
				btn.text = str(item.cost) + " CR"
				btn.disabled = true
			else:
				btn.text = "BUY"
				btn.disabled = false

func _on_buy(item_id: String) -> void:
	for item in SHOP_ITEMS:
		if item.id != item_id:
			continue

		if item_id == "char_red_small":
			SaveManager.set_selected_character("red_small")
			_update_display()
			return

		if item_id == "char_red_heavy":
			if SaveManager.has_character("red_heavy"):
				SaveManager.set_selected_character("red_heavy")
				_update_display()
				return
			if SaveManager.spend_credits(item.cost):
				SaveManager.unlock_character("red_heavy")
				SaveManager.set_selected_character("red_heavy")
				_update_display()
			return

func _on_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menus/main_menu.tscn")
