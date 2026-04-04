extends Control

# ── Prices — edit these to set individual unlock costs ────────
var PRICES: Dictionary = {
	"red_small": 0,
	"blue_small": 100,
	"green_small": 100,
	"grey_small": 100,
	"red_heavy": 250,
	"blue_heavy": 300,
	"green_heavy": 300,
	"grey_heavy": 300,
}

var DISPLAY_NAMES: Dictionary = {
	"red_small": "Red Light",
	"blue_small": "Blue Light",
	"green_small": "Green Light",
	"grey_small": "Grey Light",
	"red_heavy": "Red Heavy",
	"blue_heavy": "Blue Heavy",
	"green_heavy": "Green Heavy",
	"grey_heavy": "Grey Heavy",
}

const CHARACTER_STATS: Dictionary = {
	"red_small":  {"hp": 20, "dmg": 2, "fire_rate": 0.3, "move_speed": 250.0, "dash_cooldown": 3.0},
	"blue_small": {"hp": 20, "dmg": 2, "fire_rate": 0.3, "move_speed": 250.0, "dash_cooldown": 3.0},
	"green_small":{"hp": 20, "dmg": 2, "fire_rate": 0.3, "move_speed": 250.0, "dash_cooldown": 3.0},
	"grey_small": {"hp": 20, "dmg": 2, "fire_rate": 0.3, "move_speed": 250.0, "dash_cooldown": 3.0},
	"red_heavy":  {"hp": 30, "dmg": 4, "fire_rate": 0.7, "move_speed": 200.0, "dash_cooldown": 5.0},
	"blue_heavy": {"hp": 30, "dmg": 4, "fire_rate": 0.7, "move_speed": 200.0, "dash_cooldown": 5.0},
	"green_heavy":{"hp": 30, "dmg": 4, "fire_rate": 0.7, "move_speed": 200.0, "dash_cooldown": 5.0},
	"grey_heavy": {"hp": 30, "dmg": 4, "fire_rate": 0.7, "move_speed": 200.0, "dash_cooldown": 5.0},
}

# ── Node refs — these match the scene tree nodes ─────────────
@onready var back_button: Button = $UI/BackButton
@onready var credits_label: Label = $UI/CreditsLabel
@onready var stats_card: Panel = $CharacterStatsCard
@onready var stats_name_label: Label = $CharacterStatsCard/Margin/VBox/SelectedName
@onready var hp_value_label: Label = $CharacterStatsCard/Margin/VBox/Stats/HPRow/Value
@onready var dmg_value_label: Label = $CharacterStatsCard/Margin/VBox/Stats/DMGRow/Value
@onready var fire_rate_value_label: Label = $CharacterStatsCard/Margin/VBox/Stats/FireRateRow/Value
@onready var move_speed_value_label: Label = $CharacterStatsCard/Margin/VBox/Stats/MoveSpeedRow/Value
@onready var dash_cooldown_value_label: Label = $CharacterStatsCard/Margin/VBox/Stats/DashCooldownRow/Value

# Character slots — each is a Control node in the scene, named by character id.
# Each slot expects these children:
#   - Sprite (any node, just for visuals — you handle it)
#   - Overlay (ColorRect) — darkened when locked, hidden when owned
#   - LockLabel (Label) — shown when locked
#   - PriceLabel (Label) — shows cost / OWNED / EQUIPPED
#   - ActionButton (Button) — BUY / SELECT / SELECTED

const ALL_CHAR_IDS: Array = [
	"red_small", "blue_small", "green_small", "grey_small",
	"red_heavy", "blue_heavy", "green_heavy", "grey_heavy",
]

var _stats_card: Panel = null
var _stats_name_label: Label = null
var _stats_values: Dictionary = {}
var _character_name_colors: Dictionary = {}

func _ready() -> void:
	_stats_card = stats_card
	_stats_name_label = stats_name_label
	_stats_values = {
		"hp": hp_value_label,
		"dmg": dmg_value_label,
		"fire_rate": fire_rate_value_label,
		"move_speed": move_speed_value_label,
		"dash_cooldown": dash_cooldown_value_label,
	}
	back_button.pressed.connect(_on_back)
	for id in ALL_CHAR_IDS:
		var slot_node: Control = get_node_or_null(id)
		if not slot_node:
			continue
		slot_node.mouse_filter = Control.MOUSE_FILTER_STOP
		slot_node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
		slot_node.gui_input.connect(_on_slot_gui_input.bind(id))
		_set_slot_children_mouse_ignore(slot_node)
		var btn: Button = slot_node.get_node("ActionButton")
		btn.pressed.connect(_on_slot_pressed.bind(id))
		var dark_bg := StyleBoxFlat.new()
		dark_bg.bg_color = Color(0.03, 0.03, 0.06, 0.95)
		dark_bg.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("normal", dark_bg)
		var dark_bg_hover := StyleBoxFlat.new()
		dark_bg_hover.bg_color = Color(0.08, 0.08, 0.12, 0.95)
		dark_bg_hover.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("hover", dark_bg_hover)
		var dark_bg_pressed := StyleBoxFlat.new()
		dark_bg_pressed.bg_color = Color(0.02, 0.02, 0.04, 0.98)
		dark_bg_pressed.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("pressed", dark_bg_pressed)
		var dark_bg_disabled := StyleBoxFlat.new()
		dark_bg_disabled.bg_color = Color(0.02, 0.02, 0.05, 0.95)
		dark_bg_disabled.set_corner_radius_all(4)
		btn.add_theme_stylebox_override("disabled", dark_bg_disabled)
	_update_all()


func _set_slot_children_mouse_ignore(root: Control) -> void:
	for child in root.get_children():
		if child is Control:
			(child as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
			_set_slot_children_mouse_ignore(child as Control)


func _on_slot_gui_input(event: InputEvent, id: String) -> void:
	if not (event is InputEventMouseButton):
		return
	var mb := event as InputEventMouseButton
	if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
		return
	var slot_node: Control = get_node_or_null(id)
	if not slot_node:
		return
	var btn: Button = slot_node.get_node_or_null("ActionButton")
	if btn and btn.disabled:
		return
	get_viewport().set_input_as_handled()
	_on_slot_pressed(id)

func _update_all() -> void:
	credits_label.text = "Credits: " + str(SaveManager.get_credits())
	var selected := SaveManager.get_selected_character()
	_update_stats_card(selected)

	for id in ALL_CHAR_IDS:
		var slot_node: Control = get_node_or_null(id)
		if not slot_node:
			continue
		var cost: int = PRICES.get(id, 0)
		var owned := (cost == 0) or SaveManager.has_character(id)
		var is_selected: bool = (selected == id)

		var overlay: ColorRect = slot_node.get_node("Overlay")
		var lock_label: Label = slot_node.get_node("LockLabel")
		var price_label: Label = slot_node.get_node("PriceLabel")
		var btn: Button = slot_node.get_node("ActionButton")

		if owned:
			overlay.visible = false
			lock_label.visible = false
			price_label.visible = false
			if is_selected:
				btn.text = "SELECTED"
				btn.disabled = true
			else:
				btn.text = "SELECT"
				btn.disabled = false
		else:
			overlay.visible = true
			lock_label.visible = true
			price_label.visible = false
			if SaveManager.get_credits() >= cost:
				btn.text = str(cost) + " CR"
				btn.disabled = false
				btn.add_theme_color_override("font_color", Color(1.0, 1.0, 1.0))
			else:
				btn.text = str(cost) + " CR"
				btn.disabled = true
				btn.add_theme_color_override("font_disabled_color", Color(0.9, 0.2, 0.2))

func _on_slot_pressed(id: String) -> void:
	var cost: int = PRICES.get(id, 0)
	var owned := (cost == 0) or SaveManager.has_character(id)

	if owned:
		SaveManager.set_selected_character(id)
		AudioManager.play_sfx("ui_click")
	else:
		if SaveManager.spend_credits(cost):
			SaveManager.unlock_character(id)
			SaveManager.set_selected_character(id)
			AudioManager.play_sfx("ui_click")
	_update_all()
	_play_selected_anim(id)

func _play_selected_anim(id: String) -> void:
	var slot_node: Control = get_node_or_null(id)
	if not slot_node:
		return
	var sprite: AnimatedSprite2D = slot_node.get_node_or_null("Sprite")
	if not sprite or not sprite.sprite_frames:
		return
	if not sprite.sprite_frames.has_animation("selected"):
		return
	sprite.play("selected")
	await sprite.animation_finished
	if is_instance_valid(sprite):
		sprite.play("idle")

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("pause"):
		get_viewport().set_input_as_handled()
		_on_back()

func _on_back() -> void:
	SceneTransition.change_scene("res://scenes/menus/main_menu.tscn")


func _update_stats_card(character_id: String) -> void:
	if not _stats_card or not _stats_name_label:
		return
	var stats: Dictionary = CHARACTER_STATS.get(character_id, {})
	if stats.is_empty():
		return
	_stats_name_label.text = str(DISPLAY_NAMES.get(character_id, character_id)).to_upper()
	_stats_name_label.add_theme_color_override("font_color", _get_character_asset_color(character_id))
	_set_stat_text("hp", str(int(stats.get("hp", 0))))
	_set_stat_text("dmg", str(int(stats.get("dmg", 0))))
	_set_stat_text("fire_rate", "%.2fs" % float(stats.get("fire_rate", 0.0)))
	_set_stat_text("move_speed", str(int(stats.get("move_speed", 0.0))))
	_set_stat_text("dash_cooldown", "%.1fs" % float(stats.get("dash_cooldown", 0.0)))


func _set_stat_text(key: String, value: String) -> void:
	var lbl := _stats_values.get(key, null) as Label
	if lbl:
		lbl.text = value


func _get_character_asset_color(character_id: String) -> Color:
	if _character_name_colors.has(character_id):
		return _character_name_colors[character_id]

	var fallback := Color(0.6, 0.95, 0.9, 1.0)
	var slot_node := get_node_or_null(character_id) as Control
	if not slot_node:
		_character_name_colors[character_id] = fallback
		return fallback

	var sprite := slot_node.get_node_or_null("Sprite") as AnimatedSprite2D
	if not sprite or not sprite.sprite_frames:
		_character_name_colors[character_id] = fallback
		return fallback

	var anim := StringName("idle")
	if not sprite.sprite_frames.has_animation(anim):
		var names := sprite.sprite_frames.get_animation_names()
		if names.is_empty():
			_character_name_colors[character_id] = fallback
			return fallback
		anim = names[0]

	var tex := sprite.sprite_frames.get_frame_texture(anim, 0)
	var picked := _sample_tint_from_texture(tex, fallback)
	_character_name_colors[character_id] = picked
	return picked


func _sample_tint_from_texture(tex: Texture2D, fallback: Color) -> Color:
	if tex == null:
		return fallback

	var img: Image = null
	var region := Rect2()

	if tex is AtlasTexture:
		var atlas_tex := tex as AtlasTexture
		if atlas_tex.atlas == null:
			return fallback
		img = atlas_tex.atlas.get_image()
		region = atlas_tex.region
	else:
		img = tex.get_image()
		if img:
			region = Rect2(0, 0, img.get_width(), img.get_height())

	if img == null:
		return fallback

	var x0 := clampi(int(region.position.x), 0, img.get_width() - 1)
	var y0 := clampi(int(region.position.y), 0, img.get_height() - 1)
	var x1 := clampi(int(region.end.x), x0 + 1, img.get_width())
	var y1 := clampi(int(region.end.y), y0 + 1, img.get_height())

	var buckets: Dictionary = {}
	var bucket_sum: Dictionary = {}
	var bucket_count: Dictionary = {}
	for y in range(y0, y1, 2):
		for x in range(x0, x1, 2):
			var c := img.get_pixel(x, y)
			if c.a < 0.45:
				continue
			var v := maxf(c.r, maxf(c.g, c.b))
			var min_v := minf(c.r, minf(c.g, c.b))
			var sat := 0.0
			if v > 0.0001:
				sat = (v - min_v) / v
			# Ignore outlines/shadows and near-white highlights.
			if sat < 0.28 or v < 0.18 or v > 0.94:
				continue
			# Quantize to find dominant body color family.
			var qr := int(floor(c.r * 11.0))
			var qg := int(floor(c.g * 11.0))
			var qb := int(floor(c.b * 11.0))
			var key := "%d_%d_%d" % [qr, qg, qb]
			var weight := c.a * (0.5 + sat)
			buckets[key] = float(buckets.get(key, 0.0)) + weight
			bucket_sum[key] = (bucket_sum.get(key, Vector3.ZERO) as Vector3) + Vector3(c.r, c.g, c.b)
			bucket_count[key] = int(bucket_count.get(key, 0)) + 1

	if buckets.is_empty():
		return fallback

	var best_key := ""
	var best_weight := -1.0
	for key in buckets.keys():
		var w := float(buckets[key])
		if w > best_weight:
			best_weight = w
			best_key = key

	if best_key == "":
		return fallback

	var cnt := maxi(int(bucket_count.get(best_key, 0)), 1)
	var sum := bucket_sum.get(best_key, Vector3.ZERO) as Vector3
	var avg := sum / float(cnt)
	var picked := Color(avg.x, avg.y, avg.z, 1.0)
	# Keep it punchy/readable like in-game palette labels.
	picked.r = clampf(picked.r * 1.15, 0.0, 1.0)
	picked.g = clampf(picked.g * 1.15, 0.0, 1.0)
	picked.b = clampf(picked.b * 1.15, 0.0, 1.0)
	return picked
