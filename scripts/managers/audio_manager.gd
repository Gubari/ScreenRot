extends Node

# --- Music ---
var music_player: AudioStreamPlayer

# --- SFX pool (multiple simultaneous sounds) ---
const SFX_POOL_SIZE := 8
var sfx_players: Array[AudioStreamPlayer] = []
var sfx_index: int = 0

# --- Sound library (auto-loaded from assets/audio/sfx/) ---
var sfx_library: Dictionary = {}

# Music tracks - drop .ogg files into assets/audio/music/
var music_library: Dictionary = {}
var _music_was_playing_before_pause: bool = false
var _pending_music_track: String = ""
var _web_unlocked: bool = false

const SFX_PATH := "res://assets/audio/sfx/"
const MUSIC_PATH := "res://assets/audio/music/"

const PRELOADED_SFX := {
	"coin_collect": preload("res://assets/audio/sfx/coin_collect.wav"),
	"dash": preload("res://assets/audio/sfx/dash.wav"),
	"defrag": preload("res://assets/audio/sfx/defrag.wav.ogg"),
	"enemy_kill": preload("res://assets/audio/sfx/enemy_kill.wav"),
	"game_lost": preload("res://assets/audio/sfx/game_lost.wav"),
	"game_won": preload("res://assets/audio/sfx/game_won.wav"),
	"player_damage": preload("res://assets/audio/sfx/player_damage.wav.ogg"),
	"screen_fragment": preload("res://assets/audio/sfx/screen_fragment.ogg"),
	"shoot": preload("res://assets/audio/sfx/shoot.ogg"),
	"ui_click": preload("res://assets/audio/sfx/ui_click.wav"),
	"wave_clear": preload("res://assets/audio/sfx/wave_clear.wav"),
}
const PRELOADED_MUSIC := {
	"menu": preload("res://assets/audio/music/menu.ogg"),
	"gameplay": preload("res://assets/audio/music/gameplay.ogg"),
}

const KNOWN_SFX_KEYS := [
	"shoot", "enemy_hit", "enemy_kill", "player_damage", "player_death", "defrag",
	"ui_click", "ui_popup", "wave_clear", "level_up", "boss_enter", "boss_death",
	"error", "pickup", "dash", "screen_fragment", "coin_collect", "game_lost", "game_won",
]
const KNOWN_MUSIC_KEYS := ["menu", "gameplay", "boss"]

func _ready() -> void:
	set_process_input(true)
	set_process_unhandled_input(true)

	music_player = AudioStreamPlayer.new()
	music_player.bus = "Music"
	music_player.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(music_player)

	for i in SFX_POOL_SIZE:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		player.process_mode = Node.PROCESS_MODE_ALWAYS
		add_child(player)
		sfx_players.append(player)

	_load_sfx_library()
	_load_music_library()
	_hook_ui_buttons_recursive(get_tree().root)
	get_tree().node_added.connect(_on_node_added)

func _load_sfx_library() -> void:
	for key in PRELOADED_SFX.keys():
		sfx_library[key] = PRELOADED_SFX[key]

	var dir := DirAccess.open(SFX_PATH)
	if not dir:
		return
	var loaded_any := false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			if _is_audio_file(file_name):
				var key := _strip_audio_extensions(file_name)
				var stream = load(SFX_PATH + file_name)
				if stream:
					sfx_library[key] = stream
					loaded_any = true
		file_name = dir.get_next()
	if not loaded_any and sfx_library.is_empty():
		_load_known_sfx_fallback()

func _load_music_library() -> void:
	for key in PRELOADED_MUSIC.keys():
		var stream := PRELOADED_MUSIC[key] as AudioStream
		if stream:
			_set_music_stream_loop(stream, true)
			music_library[key] = stream

	var dir := DirAccess.open(MUSIC_PATH)
	if not dir:
		return
	var loaded_any := false
	dir.list_dir_begin()
	var file_name := dir.get_next()
	while file_name != "":
		if not dir.current_is_dir() and not file_name.ends_with(".import"):
			if _is_audio_file(file_name):
				var key := _strip_audio_extensions(file_name)
				var stream: AudioStream = load(MUSIC_PATH + file_name)
				if stream:
					_set_music_stream_loop(stream, true)
					music_library[key] = stream
					loaded_any = true
		file_name = dir.get_next()
	if not loaded_any and music_library.is_empty():
		_load_known_music_fallback()

func _load_known_sfx_fallback() -> void:
	for key in KNOWN_SFX_KEYS:
		var stream := _load_audio_from_candidates(SFX_PATH, key)
		if stream:
			sfx_library[key] = stream

func _load_known_music_fallback() -> void:
	for key in KNOWN_MUSIC_KEYS:
		var stream := _load_audio_from_candidates(MUSIC_PATH, key) as AudioStream
		if stream:
			_set_music_stream_loop(stream, true)
			music_library[key] = stream

func _load_audio_from_candidates(base_path: String, key: String) -> Resource:
	var candidates: Array[String] = [
		key, key + ".wav", key + ".ogg", key + ".mp3", key + ".wav.ogg", key + ".wav.mp3",
	]
	for relative: String in candidates:
		var full_path: String = base_path + relative
		if ResourceLoader.exists(full_path):
			var stream := load(full_path)
			if stream:
				return stream
	return null

func _is_audio_file(file_name: String) -> bool:
	var ext := file_name.get_extension().to_lower()
	return ext in ["wav", "ogg", "mp3"]

func _strip_audio_extensions(file_name: String) -> String:
	var audio_exts := ["wav", "ogg", "mp3"]
	var result := file_name
	while result.get_extension().to_lower() in audio_exts:
		result = result.get_basename()
	return result

func _set_music_stream_loop(stream: AudioStream, enabled: bool) -> void:
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = enabled
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = enabled
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD if enabled else AudioStreamWAV.LOOP_DISABLED

func play_sfx(sound_name: String, volume_db: float = 0.0) -> void:
	if sound_name not in sfx_library:
		return
	var player := sfx_players[sfx_index]
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.play()
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE

func play_sfx_with_player(sound_name: String, volume_db: float = 0.0) -> AudioStreamPlayer:
	if sound_name not in sfx_library:
		return null
	var player := sfx_players[sfx_index]
	player.stream = sfx_library[sound_name]
	player.volume_db = volume_db
	player.play()
	sfx_index = (sfx_index + 1) % SFX_POOL_SIZE
	return player

func play_music(track_name: String, volume_db: float = 0.0) -> void:
	if track_name not in music_library:
		return
	if music_player.stream == music_library[track_name] and music_player.playing and not music_player.stream_paused:
		return
	if OS.get_name() == "Web" and not _web_unlocked:
		_pending_music_track = track_name
		return
	music_player.stream = music_library[track_name]
	music_player.volume_db = volume_db
	music_player.stream_paused = false
	music_player.play()

func stop_music(fade_time: float = 0.0) -> void:
	if not music_player.playing:
		return
	if fade_time <= 0.0:
		music_player.stop()
		music_player.stream_paused = false
	else:
		var tween := create_tween()
		tween.tween_property(music_player, "volume_db", -40.0, fade_time)
		tween.tween_callback(func():
			music_player.stop()
			music_player.stream_paused = false
		)

func pause_music() -> void:
	_music_was_playing_before_pause = music_player.playing
	if music_player.playing:
		music_player.stream_paused = true

func resume_music() -> void:
	if _music_was_playing_before_pause and music_player.stream:
		music_player.stream_paused = false
	_music_was_playing_before_pause = false

func has_sfx(sound_name: String) -> bool:
	return sound_name in sfx_library

func has_music(track_name: String) -> bool:
	return track_name in music_library

func is_web_audio_unlocked() -> bool:
	return _web_unlocked

func notify_user_gesture() -> void:
	if OS.get_name() != "Web":
		return
	if not _web_unlocked:
		_web_unlocked = true
	_try_resume_web_audio_context()
	if _pending_music_track != "":
		var pending := _pending_music_track
		_pending_music_track = ""
		call_deferred("play_music", pending)
	elif music_player.stream and not music_player.playing:
		call_deferred("_resume_current_music_if_any")

func _resume_current_music_if_any() -> void:
	if music_player.stream and not music_player.playing:
		music_player.play()

var _last_ui_click_ms: int = -100000

func _input(event: InputEvent) -> void:
	_handle_web_audio_unlock(event)
	if event is InputEventMouseButton \
			and event.button_index == MOUSE_BUTTON_LEFT \
			and event.pressed:
		var vp := get_viewport()
		var hovered := vp.gui_get_hovered_control()
		if hovered and hovered.is_visible_in_tree() \
				and hovered.mouse_default_cursor_shape == Control.CURSOR_POINTING_HAND:
			_play_ui_click()

func _unhandled_input(event: InputEvent) -> void:
	_handle_web_audio_unlock(event)

func _handle_web_audio_unlock(event: InputEvent) -> void:
	if OS.get_name() != "Web" or _web_unlocked:
		return
	var is_user_gesture := false
	if event is InputEventMouseButton and event.pressed:
		is_user_gesture = true
	elif event is InputEventKey and event.pressed and not event.echo:
		is_user_gesture = true
	elif event is InputEventJoypadButton and event.pressed:
		is_user_gesture = true
	elif event is InputEventScreenTouch and event.pressed:
		is_user_gesture = true
	if not is_user_gesture:
		return
	notify_user_gesture()

func _try_resume_web_audio_context() -> void:
	if not OS.has_feature("web"):
		return
	if not ClassDB.class_exists("JavaScriptBridge"):
		return
	JavaScriptBridge.eval("(function(){try{var c=[];if(globalThis.Module){c.push(Module.audioContext);c.push(Module.godotAudioContext);}c.push(globalThis.godotAudioContext);for(var i=0;i<c.length;i++){var ctx=c[i];if(ctx&&ctx.state==='suspended'&&ctx.resume){ctx.resume();}}}catch(e){}})();", true)

func _on_node_added(node: Node) -> void:
	_maybe_connect_ui_click(node)

func _hook_ui_buttons_recursive(n: Node) -> void:
	_maybe_connect_ui_click(n)
	for child in n.get_children():
		if child is Node:
			_hook_ui_buttons_recursive(child)

func _maybe_connect_ui_click(node: Node) -> void:
	if node is BaseButton:
		var btn := node as BaseButton
		if not btn.pressed.is_connected(Callable(self, "_play_ui_click")):
			btn.pressed.connect(Callable(self, "_play_ui_click"))

func _play_ui_click() -> void:
	var now := Time.get_ticks_msec()
	if now - _last_ui_click_ms < 80:
		return
	_last_ui_click_ms = now
	play_sfx("ui_click")
