extends Node

const SAVE_PATH := "user://save_data.json"

var data: Dictionary = {
	"credits": 0,
	"high_score": 0,
	"purchased_upgrades": [],
	"master_volume": 1.0,
	"music_volume": 0.8,
	"sfx_volume": 0.8,
	"muted": false,
	"fullscreen": false,
}

func _ready() -> void:
	load_game()
	apply_audio_settings()
	apply_display_settings()

func get_credits() -> int:
	return data.credits

func add_credits(amount: int) -> void:
	data.credits += amount
	save_game()

func spend_credits(amount: int) -> bool:
	if data.credits < amount:
		return false
	data.credits -= amount
	save_game()
	return true

func get_high_score() -> int:
	return data.high_score

func update_high_score(score: int) -> bool:
	if score > data.high_score:
		data.high_score = score
		save_game()
		return true
	return false

func has_upgrade(upgrade_id: String) -> bool:
	return upgrade_id in data.purchased_upgrades

func purchase_upgrade(upgrade_id: String) -> void:
	if upgrade_id not in data.purchased_upgrades:
		data.purchased_upgrades.append(upgrade_id)
		save_game()

func save_game() -> void:
	var file := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(data))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if not file:
		return
	var json := JSON.new()
	if json.parse(file.get_as_text()) == OK and json.data is Dictionary:
		var loaded: Dictionary = json.data
		for key in loaded:
			data[key] = loaded[key]

func set_setting(key: String, value: Variant) -> void:
	data[key] = value
	save_game()
	apply_audio_settings()

func get_setting(key: String, default: Variant = null) -> Variant:
	return data.get(key, default)

func apply_audio_settings() -> void:
	var master_idx := AudioServer.get_bus_index("Master")
	if master_idx >= 0:
		var vol: float = data.get("master_volume", 1.0)
		AudioServer.set_bus_volume_db(master_idx, linear_to_db(vol))
		AudioServer.set_bus_mute(master_idx, data.get("muted", false))

	var music_idx := AudioServer.get_bus_index("Music")
	if music_idx >= 0:
		AudioServer.set_bus_volume_db(music_idx, linear_to_db(data.get("music_volume", 0.8)))

	var sfx_idx := AudioServer.get_bus_index("SFX")
	if sfx_idx >= 0:
		AudioServer.set_bus_volume_db(sfx_idx, linear_to_db(data.get("sfx_volume", 0.8)))

func apply_display_settings() -> void:
	if data.get("fullscreen", false):
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)

func reset_save() -> void:
	data = {
		"credits": 0,
		"high_score": 0,
		"purchased_upgrades": [],
		"master_volume": 1.0,
		"music_volume": 0.8,
		"sfx_volume": 0.8,
		"muted": false,
			"fullscreen": false,
	}
	save_game()
