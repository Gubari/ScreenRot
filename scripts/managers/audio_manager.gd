extends Node

# --- Music ---
var music_player: AudioStreamPlayer

# --- SFX pool (multiple simultaneous sounds) ---
const SFX_POOL_SIZE := 8
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index: int = 0

# --- Sound library (auto-loaded from assets/audio/sfx/) ---
# Just drop .wav or .ogg files into assets/audio/sfx/ with these names:
#   shoot.wav, enemy_hit.wav, enemy_kill.wav, player_damage.wav,
#   player_death.wav, defrag.wav, ui_click.wav, ui_popup.wav,
#   wave_clear.wav, level_up.wav, boss_enter.wav, boss_death.wav,
#   error.wav, pickup.wav, dash.wav
var sfx_library: Dictionary = {}

# Music tracks - drop .ogg files into assets/audio/music/
#   gameplay.ogg, menu.ogg, boss.ogg
var music_library: Dictionary = {}

const SFX_PATH := "res://assets/audio/sfx/"
const MUSIC_PATH := "res://assets/audio/music/"

func _ready() -> void:
	# Create music player
	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	add_child(music_player)

	# Create SFX player pool
	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		sfx_players.append(player)

	# Load sound files
	_load_sfx_library()
	_load_music_library()

func _load_sfx_library() -> void:
	var dir := DirAccess.open(SFX_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			if _is_audio_file(file_name):
				var key := _strip_audio_extensions(file_name)
				var stream = load(SFX_PATH + file_name)
				if stream:
					sfx_library[key] = stream
		file_name = dir.get_next()

func _load_music_library() -> void:
	var dir := DirAccess.open(MUSIC_PATH)
	if not dir:
		return
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			if _is_audio_file(file_name):
				var key := _strip_audio_extensions(file_name)
				var stream = load(MUSIC_PATH + file_name)
				if stream:
					music_library[key] = stream
		file_name = dir.get_next()

func _is_audio_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in ["wav", "ogg", "mp3"]

## Strip all audio extensions from filename (handles double extensions like shoot.wav.ogg)
func _strip_audio_extensions(file_name: String) -> String:
	var audio_exts := ["wav", "ogg", "mp3"]
	var result := file_name
	while result.get_extension().to_lower() in audio_exts:
		result = result.get_basename()
	return result

# --- PUBLIC API ---

## Play a sound effect by name (e.g. "shoot", "enemy_kill")
## Silently does nothing if the sound doesn't exist yet
func play_sfx(sound_name: String, volume_db: float = 0.0) -> void:
	if sound_name not in sfx_library:
		return
	var player := sfx_players[sfx_index]
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.play()
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE

## Play music track by name (e.g. "gameplay", "menu", "boss")
## Loops by default. Silently does nothing if track doesn't exist yet
func play_music(track_name: String, volume_db: float = 0.0) -> void:
	if track_name not in music_library:
		return
	if music_player.stream == music_library[track_name] and music_player.playing:
		return # Already playing this track
	music_player.stream = music_library[track_name]
	music_player.volume_db = volume_db
	music_player.play()

## Stop music with optional fade out
func stop_music(fade_time: float = 0.0) -> void:
	if not music_player.playing:
		return
	if fade_time <= 0.0:
		music_player.stop()
	else:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_time)
		tween.tween_callback(music_player.stop)

## Check if a sound exists in the library
func has_sfx(sound_name: String) -> bool:
	return sound_name in sfx_library

func has_music(track_name: String) -> bool:
	return track_name in music_library
