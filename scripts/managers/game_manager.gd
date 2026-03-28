extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var gameplay_hud = $HUD/GameplayHUD
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var wave_manager: WaveManager = $WaveManager
@onready var game_over_screen: CanvasLayer = $GameOver
@onready var upgrade_select: CanvasLayer = $UpgradeSelect
@onready var debris_overlay: CanvasLayer = $DebrisOverlay
@onready var dungeon_map: Node2D = $DungeonMap
@onready var screen_closing: CanvasLayer = $ScreenClosing

const PLAYER_SCENES: Dictionary = {
	"red_small": preload("res://scenes/player/player.tscn"),
	"red_heavy": preload("res://scenes/player/player_heavy.tscn"),
	"blue_small": preload("res://scenes/player/player_blue.tscn"),
	"blue_heavy": preload("res://scenes/player/player_heavy_blue.tscn"),
	"green_small": preload("res://scenes/player/player_green.tscn"),
	"green_heavy": preload("res://scenes/player/player_heavy_green.tscn"),
	"grey_small": preload("res://scenes/player/player_grey.tscn"),
	"grey_heavy": preload("res://scenes/player/player_heavy_grey.tscn"),
}

var current_wave: int = 0
var wave_active: bool = false

var kills_this_wave: int = 0
var run_credits: int = 0

# Ensure win/loss sounds play only once per run.
var _played_game_lost: bool = false
var _played_game_won: bool = false
var _game_over_started: bool = false
var _game_won_sfx_player: AudioStreamPlayer = null

const TUTORIAL_SCENE := preload("res://scenes/hud/tutorial_overlay.tscn")
@export var force_tutorial: bool = false

# Boss tracking
var _active_boss: BossBase = null
var _fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

func _ready() -> void:
	add_to_group("game_manager")
	_swap_player_if_needed()
	# Configure wave manager based on selected game mode
	wave_manager.is_endless_mode = GameMode.is_challenge()
	# Generate dungeon map first
	if dungeon_map and dungeon_map.has_method("generate"):
		dungeon_map.generate()
		# get_map_rect() returns coords in DungeonMap local space — offset to world space.
		var local_rect: Rect2 = dungeon_map.get_map_rect()
		var map_rect := Rect2(local_rect.position + dungeon_map.global_position, local_rect.size)

		# Pass map bounds to player
		player.map_rect = map_rect
		player.setup_camera_limits(map_rect)
		player.global_position = dungeon_map.get_player_spawn()

		# Pass map bounds and map reference to enemy spawner
		enemy_spawner.map_rect = map_rect
		enemy_spawner.dungeon_map = dungeon_map

		# Pass map size to debris overlay
		if debris_overlay and debris_overlay.has_method("setup_map_size"):
			debris_overlay.setup_map_size(map_rect.size)

	player.player_damaged.connect(_on_player_damaged)
	player.score_changed.connect(_on_score_changed)
	player.player_died.connect(_on_player_died)
	player.defrag_used.connect(_on_player_defrag_used)
	enemy_spawner.all_enemies_dead.connect(_on_all_enemies_dead)
	enemy_spawner.enemy_killed_global.connect(_on_enemy_killed)
	upgrade_select.upgrade_chosen.connect(_on_upgrade_chosen)
	if debris_overlay and debris_overlay.has_signal("debris_changed"):
		debris_overlay.debris_changed.connect(_on_debris_changed)
	if screen_closing and screen_closing.has_signal("screen_percent_changed"):
		screen_closing.screen_percent_changed.connect(_on_screen_percent_changed)
	if screen_closing and screen_closing.has_signal("screen_fully_closed"):
		screen_closing.screen_fully_closed.connect(_on_screen_fully_closed)
	update_hud()
	gameplay_hud.hide_boss_bar()
	gameplay_hud.hide_wave_label()
	AudioManager.play_music("gameplay")
	if force_tutorial or not SaveManager.get_setting("tutorial_seen", false):
		_show_tutorial()
	else:
		await get_tree().create_timer(1.0).timeout
		start_next_wave()

func _show_tutorial() -> void:
	await get_tree().process_frame
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.reset_smoothing()
		cam.force_update_scroll()
	var tutorial = TUTORIAL_SCENE.instantiate()
	add_child(tutorial)
	tutorial.tutorial_finished.connect(_on_tutorial_finished)

func _on_tutorial_finished() -> void:
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _swap_player_if_needed() -> void:
	var selected := SaveManager.get_selected_character()
	var packed: PackedScene = PLAYER_SCENES.get(selected, null)
	if packed == null:
		return
	# If already correct, do nothing.
	if player and player.scene_file_path == packed.resource_path:
		return
	var parent := player.get_parent()
	var old_pos := player.global_position
	var new_player := packed.instantiate() as CharacterBody2D
	new_player.name = "Player"
	parent.add_child(new_player)
	new_player.global_position = old_pos
	player.queue_free()
	player = new_player

func _process(_delta: float) -> void:
	gameplay_hud.update_dash(player.get_dash_percent())
	# Auto-detect boss if not connected yet
	if not _active_boss or not is_instance_valid(_active_boss):
		_try_connect_boss()
	# Update boss health bar
	if _active_boss and is_instance_valid(_active_boss):
		var hp_pct := (float(_active_boss.current_hp) / float(_active_boss.max_hp)) * 100.0
		gameplay_hud.update_boss_hp(hp_pct)
		_update_boss_bar_color()
	if OS.is_debug_build() and Input.is_key_pressed(KEY_U):
		_debug_skip_wave()

func start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	kills_this_wave = 0

	var queue: Array = get_wave_data(current_wave)
	enemy_spawner.spawn_margin = wave_manager.get_spawn_radius(current_wave)
	enemy_spawner.spawn_in_center = wave_manager.get_spawn_in_center(current_wave)
	enemy_spawner.center_position = wave_manager.get_spawn_center_position(current_wave)

	if wave_manager.get_is_boss_wave(current_wave):
		await _do_boss_cinematic()
		return

	var wave_name := wave_manager.get_wave_name(current_wave)
	gameplay_hud.show_wave(wave_name)
	gameplay_hud.fade_wave_label()
	enemy_spawner.start_spawning(queue)

func _do_boss_cinematic() -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if not cam:
		return

	# Disable player input during cinematic
	player.set_physics_process(false)

	var boss_pos := wave_manager.get_spawn_center_position(current_wave)
	var original_zoom := cam.zoom
	var cinematic_zoom := Vector2(1.1, 1.1)

	# Reparent camera to scene root so we can freely tween its position
	var original_parent := cam.get_parent()
	var original_cam_global_pos := cam.global_position
	cam.position_smoothing_enabled = false
	original_parent.remove_child(cam)
	add_child(cam)
	cam.global_position = original_cam_global_pos

	# Pan to boss center + zoom in
	var tween_to := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_to.set_parallel(true)
	tween_to.tween_property(cam, "global_position", boss_pos, 1.2)
	tween_to.tween_property(cam, "zoom", cinematic_zoom, 1.2)
	await tween_to.finished

	# Show BOSS FIGHT label and spawn boss while camera is at center
	gameplay_hud.show_wave("BOSS FIGHT!")
	enemy_spawner.start_spawning(get_wave_data(current_wave))
	await get_tree().create_timer(1.5).timeout
	gameplay_hud.fade_wave_label()

	# Pan back to player + zoom out
	var tween_back := create_tween().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	tween_back.set_parallel(true)
	tween_back.tween_property(cam, "global_position", player.global_position, 1.2)
	tween_back.tween_property(cam, "zoom", original_zoom, 1.2)
	await tween_back.finished

	# Return camera back to player
	remove_child(cam)
	original_parent.add_child(cam)
	cam.position = Vector2.ZERO
	cam.position_smoothing_enabled = true
	cam.reset_smoothing()

	# Re-enable player input
	player.set_physics_process(true)

func get_wave_data(wave: int) -> Array:
	return wave_manager.get_wave_data(wave)

# ── Boss connection ───────────────────────────────────────────

func _try_connect_boss() -> void:
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy is BossBase:
			_connect_boss(enemy as BossBase)
			return

func _connect_boss(boss: BossBase) -> void:
	_active_boss = boss
	boss.screen_closing = screen_closing
	boss.dungeon_map = dungeon_map
	boss.phase_changed.connect(_on_boss_phase_changed)
	boss.request_screen_shrink.connect(_on_boss_screen_shrink)
	boss.request_screen_restore.connect(_on_boss_screen_restore)
	boss.request_zoom.connect(_on_boss_zoom)
	boss.fragment_spawn_requested.connect(_on_boss_fragment_spawn)
	boss.boss_wave_requested.connect(_on_boss_wave_requested)
	boss.boss_defeated.connect(_on_boss_defeated)
	# Show boss health bar
	gameplay_hud.show_boss_bar(boss.boss_id.to_upper())
	# Start screen shrink for whatever phase boss is already in
	match boss.current_phase:
		1: _on_boss_screen_shrink(boss.p1_shrink_rate)
		2: _on_boss_screen_shrink(boss.p2_shrink_rate)
		3: _on_boss_screen_shrink(boss.p3_shrink_rate)

func _on_boss_phase_changed(_phase: int) -> void:
	_update_boss_bar_color()

func _on_boss_wave_requested(queue: Array) -> void:
	enemy_spawner.add_spawning(queue)

func _on_boss_screen_shrink(rate: float) -> void:
	if _game_over_started:
		return
	if screen_closing:
		if rate > 0.0:
			screen_closing.shrink_rate = rate
			screen_closing.start(rate)
		else:
			screen_closing.stop()

func _on_boss_screen_restore(amount: float) -> void:
	if _game_over_started:
		return
	if screen_closing:
		screen_closing.restore(amount)

func _on_boss_zoom(target_zoom: float) -> void:
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var tw := create_tween()
		tw.tween_property(cam, "zoom", Vector2(target_zoom, target_zoom), 0.5).set_trans(Tween.TRANS_QUAD)

func _on_boss_fragment_spawn(world_pos: Vector2, value: float) -> void:
	var frag = _fragment_scene.instantiate()
	frag.global_position = world_pos
	frag.restore_value = value
	frag.collected.connect(_on_fragment_collected)
	var scene := get_tree().current_scene
	scene.add_child(frag)
	# Default add_child appends last → draws on top of everything. Draw before Enemies
	# so fragments sit under units (same z_index: earlier in tree = behind).
	var enemies_node := scene.get_node_or_null("Enemies")
	if enemies_node:
		scene.move_child(frag, enemies_node.get_index())

func _on_fragment_collected(value: float) -> void:
	if _game_over_started:
		return
	AudioManager.play_sfx("screen_fragment")
	if screen_closing:
		screen_closing.restore(value)

func _on_screen_percent_changed(percent: float) -> void:
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss.set_screen_percent(percent)
	gameplay_hud.apply_screen_inset(percent)

func _on_screen_fully_closed() -> void:
	# Poraz kad crni okvir stigne do kraja (odvojeno od HP = 0).
	if not player or not is_instance_valid(player) or not player.visible:
		return
	if _game_over_started:
		return
	_game_over_started = true
	if screen_closing:
		screen_closing.stop()
	player.current_hp = 0
	gameplay_hud.update_hp(0, player.max_hp)
	if not _played_game_lost:
		AudioManager.stop_music(0.2)
		AudioManager.play_sfx("game_lost")
		_played_game_lost = true
	# Small delay so the player can actually hear the sound
	# game_lost.wav ~0.95s
	await get_tree().create_timer(1.1, true).timeout
	wave_active = false
	player.set_physics_process(false)
	player.visible = false
	# Clean up boss
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss = null
	gameplay_hud.hide_boss_bar()
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(player.score)
	game_over_screen.show_game_over(player.score, run_credits, "YOU DIED!", "There was not enough screen.")

func _on_boss_defeated(_boss_id: String, _score: int) -> void:
	if not _played_game_won:
		AudioManager.stop_music(0.2)
		_game_won_sfx_player = AudioManager.play_sfx_with_player("game_won")
		_played_game_won = true
	_active_boss = null
	gameplay_hud.hide_boss_bar()
	# Don't delay sound here; boss_defeated is emitted after the boss death animation.
	# Delay (if any) should happen before showing the win screen UI.
	_game_over_started = true
	# Reset screen effects
	if screen_closing:
		screen_closing.reset_to_full()
	# Reset camera zoom
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var tw := create_tween()
		tw.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.8).set_trans(Tween.TRANS_QUAD)
	# Clean up remaining enemies and fragments
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	enemy_spawner.enemies_alive = 0
	enemy_spawner.interrupt_scheduled_spawns()
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	_on_all_waves_completed()

func _update_boss_bar_color() -> void:
	if not _active_boss or not is_instance_valid(_active_boss):
		return
	var hp_pct := float(_active_boss.current_hp) / float(_active_boss.max_hp)
	var color: Color
	if hp_pct > 0.6:
		color = Color.GREEN
	elif hp_pct > 0.3:
		color = Color.ORANGE
	else:
		color = Color.RED
	gameplay_hud.update_boss_bar_color(color)

# ── Standard wave/enemy handling ──────────────────────────────

func _on_enemy_killed(pos: Vector2, type: String) -> void:
	kills_this_wave += 1
	# Clean Kill upgrade: chance to skip debris
	var skip_debris: bool = player.upgrade_clean_kill_chance > 0.0 and randf() < player.upgrade_clean_kill_chance
	if not skip_debris and debris_overlay and debris_overlay.has_method("add_debris"):
		debris_overlay.add_debris(pos, type)
	update_debris_display()
	update_multiplier()
	_connect_coin_pickups()

func update_multiplier() -> void:
	var debris_percent := _get_debris_percent()
	var new_mult: int
	if debris_percent < 10.0:
		new_mult = 1
	elif debris_percent < 25.0:
		new_mult = 2
	elif debris_percent < 40.0:
		new_mult = 3
	else:
		new_mult = 5
	player.set_multiplier(new_mult)
	gameplay_hud.update_multiplier(new_mult)

func update_debris_display() -> void:
	var debris_percent := _get_debris_percent()
	var color: Color
	var label_text: String
	if debris_percent < 10.0:
		color = Color.GREEN
		label_text = "CLEAN"
	elif debris_percent < 25.0:
		color = Color.YELLOW
		label_text = "MESSY"
	elif debris_percent < 40.0:
		color = Color.ORANGE
		label_text = "CHAOTIC"
	else:
		color = Color.RED
		label_text = "CRITICAL"
	gameplay_hud.update_debris(debris_percent, label_text, color)

func _get_debris_percent() -> float:
	if debris_overlay and debris_overlay.has_method("get_debris_percent"):
		return debris_overlay.get_debris_percent()
	return 0.0

func _on_debris_changed(_percent: float) -> void:
	update_debris_display()
	update_multiplier()

func _apply_post_wave_heal() -> void:
	var heal_amount: int = wave_manager.get_post_wave_heal_amount(current_wave)
	if heal_amount <= 0:
		return
	var new_hp: int = mini(player.current_hp + heal_amount, player.max_hp)
	if new_hp == player.current_hp:
		return
	player.current_hp = new_hp
	_on_player_damaged(player.current_hp)
	gameplay_hud.show_heal_notification(heal_amount)

func _on_all_enemies_dead() -> void:
	if not wave_active or _game_over_started:
		return
	wave_active = false
	gameplay_hud.show_wave(wave_manager.get_wave_name(current_wave) + " CLEARED!")
	run_credits += 10
	# Play wave clear only for non-final waves (i.e. waves before the boss/end).
	if wave_manager.has_next_wave(current_wave):
		AudioManager.play_sfx("wave_clear")
	_apply_post_wave_heal()
	_update_credits_display()

	await get_tree().create_timer(wave_manager.get_post_wave_delay(current_wave)).timeout

	if wave_manager.has_next_wave(current_wave):
		upgrade_select.show_upgrades(current_wave)
	else:
		_on_all_waves_completed()

func _on_all_waves_completed() -> void:
	gameplay_hud.show_wave("ALL WAVES CLEARED!")
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(player.score)
	if GameMode.is_classic() and not SaveManager.is_challenge_unlocked():
		SaveManager.unlock_challenge()
	if _played_game_won:
		# Wait until the actual game_won sound finishes (no fixed timer).
		if _game_won_sfx_player and _game_won_sfx_player.playing:
			await _game_won_sfx_player.finished
		game_over_screen.show_game_over(player.score, run_credits, "GAME WON", "BOSS DEFEATED!")
	else:
		game_over_screen.show_game_over(player.score, run_credits)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	if upgrade_id != "":
		_apply_upgrade(upgrade_id)
	await get_tree().create_timer(2.5).timeout
	start_next_wave()

func _apply_upgrade(upgrade_id: String) -> void:
	match upgrade_id:
		"rapid_fire":
			player.fire_rate *= 0.75
		"heavy_rounds":
			player.bullet_damage += 1
		"velocity_boost":
			player.move_speed *= 1.20
		"armor_plating":
			player.max_hp += 5
			player.current_hp += 5
			_on_player_damaged(player.current_hp)
		"double_shot":
			player.upgrade_double_shot = true
		"lucky_drops":
			player.upgrade_defrag_drop_bonus += 0.10
		"extended_pickup":
			player.upgrade_defrag_lifetime_bonus += 3.0
		"strong_defrag":
			player.upgrade_defrag_strength_bonus += 15.0
		"clean_kill":
			player.upgrade_clean_kill_chance += 0.15
		"quick_dash":
			player.dash_cooldown *= 0.75


func update_hud() -> void:
	gameplay_hud.update_hp(player.current_hp, player.max_hp)
	gameplay_hud.update_score(player.score)
	gameplay_hud.update_multiplier(player.multiplier)
	gameplay_hud.update_debris(0, "CLEAN", Color.GREEN)
	gameplay_hud.update_credits(run_credits)
	gameplay_hud.update_defrag(player.defrag_count)

func _on_player_damaged(current_hp: int) -> void:
	gameplay_hud.update_hp(current_hp, player.max_hp)

func _on_score_changed(score: int, multiplier: int) -> void:
	gameplay_hud.update_score(score)
	gameplay_hud.update_multiplier(multiplier)
	gameplay_hud.update_credits(run_credits)

func _on_player_died(final_score: int, _credits: int) -> void:
	if _game_over_started:
		return
	_game_over_started = true
	if not _played_game_lost:
		AudioManager.stop_music(0.2)
		AudioManager.play_sfx("game_lost")
		_played_game_lost = true
	# Small delay so the player can actually hear the sound
	# game_lost.wav ~0.95s
	await get_tree().create_timer(1.1, true).timeout
	wave_active = false
	# Clean up boss effects on death
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss = null
	if screen_closing:
		screen_closing.reset_to_full()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		var tw := create_tween()
		tw.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.5)
	gameplay_hud.hide_boss_bar()
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(final_score)
	if GameMode.is_challenge():
		game_over_screen.show_game_over(final_score, run_credits, "YOU DIED!", "Reached Wave " + str(current_wave))
	else:
		game_over_screen.show_game_over(final_score, run_credits)

func _update_credits_display() -> void:
	gameplay_hud.update_credits(run_credits)

func _connect_defrag_pickups() -> void:
	for pickup in get_tree().get_nodes_in_group("defrag_pickups"):
		if not pickup.collected.is_connected(_on_defrag_pickup_collected):
			pickup.lifetime = 5.0 + player.upgrade_defrag_lifetime_bonus
			pickup.collected.connect(_on_defrag_pickup_collected)

func _on_defrag_pickup_collected() -> void:
	player.defrag_count = mini(player.defrag_count + 1, player.MAX_DEFRAG)
	gameplay_hud.update_defrag(player.defrag_count)

func _on_player_defrag_used() -> void:
	var clear_percent: float = 35.0 + player.upgrade_defrag_strength_bonus
	if debris_overlay and debris_overlay.has_method("defrag_clear"):
		debris_overlay.defrag_clear(clear_percent)
	gameplay_hud.update_defrag(player.defrag_count)
	update_debris_display()
	update_multiplier()

func _connect_coin_pickups() -> void:
	for coin in get_tree().get_nodes_in_group("coin_pickups"):
		if not coin.collected.is_connected(_on_coin_pickup_collected):
			coin.collected.connect(_on_coin_pickup_collected)

func _on_coin_pickup_collected() -> void:
	run_credits += player.multiplier
	AudioManager.play_sfx("coin_collect")
	_update_credits_display()

var _skip_used := false

func _debug_skip_wave() -> void:
	if not wave_active or _skip_used:
		return
	_skip_used = true
	wave_active = false
	enemy_spawner.interrupt_scheduled_spawns()
	enemy_spawner.spawning = false
	enemy_spawner.spawn_queue.clear()
	# Clean boss effects before killing enemies
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss = null
	if screen_closing:
		screen_closing.reset_to_full()
	var cam := player.get_node_or_null("Camera2D") as Camera2D
	if cam:
		cam.zoom = Vector2(1.0, 1.0)
	gameplay_hud.hide_boss_bar()
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	enemy_spawner.enemies_alive = 0
	gameplay_hud.show_wave(wave_manager.get_wave_name(current_wave) + " SKIPPED")
	await get_tree().create_timer(0.5).timeout
	_skip_used = false
	upgrade_select.show_upgrades(current_wave)
