extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var hp_label: Label = $HUD/HPLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var dash_bar: ProgressBar = $HUD/DashBar
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var debris_bar: ProgressBar = $HUD/DebrisBar
@onready var debris_label: Label = $HUD/DebrisLabel
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var wave_manager: WaveManager = $WaveManager
@onready var wave_label: Label = $HUD/WaveLabel
@onready var credits_label: Label = $HUD/CreditsLabel
@onready var game_over_screen: CanvasLayer = $GameOver
@onready var upgrade_select: CanvasLayer = $UpgradeSelect
@onready var debris_overlay: CanvasLayer = $DebrisOverlay
@onready var dungeon_map: Node2D = $DungeonMap
@onready var screen_closing: CanvasLayer = $ScreenClosing
@onready var boss_bar_container: VBoxContainer = $HUD/BossBarContainer
@onready var boss_name_label: Label = $HUD/BossBarContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $HUD/BossBarContainer/BossHealthBar

const PLAYER_SCENES: Dictionary = {
	"red_small": preload("res://scenes/player/player.tscn"),
	"red_heavy": preload("res://scenes/player/player_heavy.tscn"),
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

# Boss tracking
var _active_boss: BossBase = null
var _fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

func _ready() -> void:
	_swap_player_if_needed()
	# Generate dungeon map first
	if dungeon_map and dungeon_map.has_method("generate"):
		dungeon_map.generate()
		var map_rect: Rect2 = dungeon_map.get_map_rect()

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
	boss_bar_container.visible = false
	wave_label.visible = false
	AudioManager.play_music("gameplay")
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
	dash_bar.value = player.get_dash_percent() * 100.0
	# Auto-detect boss if not connected yet
	if not _active_boss or not is_instance_valid(_active_boss):
		_try_connect_boss()
	# Update boss health bar
	if _active_boss and is_instance_valid(_active_boss):
		boss_health_bar.value = (float(_active_boss.current_hp) / float(_active_boss.max_hp)) * 100.0
		_update_boss_bar_color()
	if OS.is_debug_build() and Input.is_key_pressed(KEY_U):
		_debug_skip_wave()

func start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	kills_this_wave = 0
	var wave_name := wave_manager.get_wave_name(current_wave)
	wave_label.text = wave_name
	wave_label.visible = true
	wave_label.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(wave_label, "modulate:a", 0.0, 1.5).set_delay(1.0)

	var queue: Array = get_wave_data(current_wave)
	enemy_spawner.spawn_margin = wave_manager.get_spawn_radius(current_wave)
	enemy_spawner.start_spawning(queue)

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
	boss.boss_defeated.connect(_on_boss_defeated)
	# Show boss health bar
	boss_name_label.text = boss.boss_id.to_upper()
	boss_health_bar.value = 100.0
	boss_bar_container.visible = true
	# Start screen shrink for whatever phase boss is already in
	match boss.current_phase:
		1: _on_boss_screen_shrink(boss.p1_shrink_rate)
		2: _on_boss_screen_shrink(boss.p2_shrink_rate)
		3: _on_boss_screen_shrink(boss.p3_shrink_rate)

func _on_boss_phase_changed(_phase: int) -> void:
	_update_boss_bar_color()

func _on_boss_screen_shrink(rate: float) -> void:
	if screen_closing:
		if rate > 0.0:
			screen_closing.shrink_rate = rate
			screen_closing.start(rate)
		else:
			screen_closing.stop()

func _on_boss_screen_restore(amount: float) -> void:
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
	get_tree().current_scene.add_child(frag)

func _on_fragment_collected(value: float) -> void:
	AudioManager.play_sfx("screen_fragment")
	if screen_closing:
		screen_closing.restore(value)

func _on_screen_percent_changed(percent: float) -> void:
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss.set_screen_percent(percent)

func _on_screen_fully_closed() -> void:
	# Screen went fully black — game over
	if not player or not is_instance_valid(player) or not player.visible:
		return
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
	player.set_physics_process(false)
	player.visible = false
	# Clean up boss
	if _active_boss and is_instance_valid(_active_boss):
		_active_boss = null
	if screen_closing:
		screen_closing.stop()
	boss_bar_container.visible = false
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
	boss_bar_container.visible = false
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
	# Clean up remaining fragments
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()

func _update_boss_bar_color() -> void:
	if not _active_boss or not is_instance_valid(_active_boss):
		return
	var hp_pct := float(_active_boss.current_hp) / float(_active_boss.max_hp)
	if hp_pct > 0.6:
		boss_health_bar.modulate = Color.GREEN
	elif hp_pct > 0.3:
		boss_health_bar.modulate = Color.ORANGE
	else:
		boss_health_bar.modulate = Color.RED

# ── Standard wave/enemy handling ──────────────────────────────

func _on_enemy_killed(pos: Vector2, type: String) -> void:
	kills_this_wave += 1
	# Clean Kill upgrade: chance to skip debris
	var skip_debris: bool = player.upgrade_clean_kill_chance > 0.0 and randf() < player.upgrade_clean_kill_chance
	if not skip_debris and debris_overlay and debris_overlay.has_method("add_debris"):
		debris_overlay.add_debris(pos, type)
	update_debris_display()
	update_multiplier()
	# Connect any new pickups spawned by enemy death
	_connect_defrag_pickups()
	_connect_coin_pickups()

func update_multiplier() -> void:
	var debris_percent := _get_debris_percent()
	var new_mult: int
	if debris_percent < 25.0:
		new_mult = 1
	elif debris_percent < 50.0:
		new_mult = 2
	elif debris_percent < 75.0:
		new_mult = 3
	else:
		new_mult = 5
	player.set_multiplier(new_mult)

func update_debris_display() -> void:
	var debris_percent := _get_debris_percent()
	debris_bar.value = debris_percent
	var color: Color
	if debris_percent < 25.0:
		color = Color.GREEN
		debris_label.text = "CLEAN"
	elif debris_percent < 50.0:
		color = Color.YELLOW
		debris_label.text = "MESSY"
	elif debris_percent < 75.0:
		color = Color.ORANGE
		debris_label.text = "CHAOTIC"
	else:
		color = Color.RED
		debris_label.text = "CRITICAL"
	debris_bar.modulate = color
	debris_label.modulate = color

func _get_debris_percent() -> float:
	if debris_overlay and debris_overlay.has_method("get_debris_percent"):
		return debris_overlay.get_debris_percent()
	return 0.0

func _on_debris_changed(_percent: float) -> void:
	update_debris_display()
	update_multiplier()

func _on_all_enemies_dead() -> void:
	if not wave_active:
		return
	wave_active = false
	wave_label.text = wave_manager.get_wave_name(current_wave) + " CLEARED!"
	wave_label.modulate.a = 1.0
	wave_label.visible = true
	run_credits += 10
	# Play wave clear only for non-final waves (i.e. waves before the boss/end).
	if wave_manager.has_next_wave(current_wave):
		AudioManager.play_sfx("wave_clear")
	_update_credits_display()

	await get_tree().create_timer(1.5).timeout

	if wave_manager.has_next_wave(current_wave):
		upgrade_select.show_upgrades(current_wave)
	else:
		_on_all_waves_completed()

func _on_all_waves_completed() -> void:
	wave_label.text = "ALL WAVES CLEARED!"
	wave_label.modulate.a = 1.0
	wave_label.visible = true
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(player.score)
	if _played_game_won:
		# Wait until the actual game_won sound finishes (no fixed timer).
		if _game_won_sfx_player and _game_won_sfx_player.playing:
			await _game_won_sfx_player.finished
		game_over_screen.show_game_over(player.score, run_credits, "GAME WON", "BOSS DEFEATED!")
	else:
		game_over_screen.show_game_over(player.score, run_credits)

func _on_upgrade_chosen(upgrade_id: String) -> void:
	_apply_upgrade(upgrade_id)
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
			player.max_hp += 1
			player.current_hp += 1
			_on_player_damaged(player.current_hp)
		"scatter_shot":
			player.upgrade_scatter_shot = true
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
	hp_label.text = "HP: " + str(player.current_hp) + "/" + str(player.max_hp)
	score_label.text = "Score: " + str(player.score)
	multiplier_label.text = "x" + str(player.multiplier)
	debris_bar.value = 0
	debris_label.text = "CLEAN"
	_update_credits_display()

func _on_player_damaged(current_hp: int) -> void:
	hp_label.text = "HP: " + str(current_hp) + "/" + str(player.max_hp)

func _on_score_changed(score: int, multiplier: int) -> void:
	score_label.text = "Score: " + str(score)
	multiplier_label.text = "x" + str(multiplier)
	_update_credits_display()

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
	boss_bar_container.visible = false
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(final_score)
	game_over_screen.show_game_over(final_score, run_credits)

func _update_credits_display() -> void:
	credits_label.text = "Credits: " + str(run_credits)

func _connect_defrag_pickups() -> void:
	for pickup in get_tree().get_nodes_in_group("defrag_pickups"):
		if not pickup.collected.is_connected(_on_defrag_pickup_collected):
			# Apply upgrade bonuses to pickup
			pickup.lifetime = 5.0 + player.upgrade_defrag_lifetime_bonus
			pickup.defrag_percent = 35.0 + player.upgrade_defrag_strength_bonus
			pickup.collected.connect(_on_defrag_pickup_collected.bind(pickup.defrag_percent))

func _on_defrag_pickup_collected(clear_percent: float) -> void:
	if debris_overlay and debris_overlay.has_method("defrag_clear"):
		debris_overlay.defrag_clear(clear_percent)
	update_debris_display()
	update_multiplier()

func _connect_coin_pickups() -> void:
	for coin in get_tree().get_nodes_in_group("coin_pickups"):
		if not coin.collected.is_connected(_on_coin_pickup_collected):
			coin.collected.connect(_on_coin_pickup_collected)

func _on_coin_pickup_collected() -> void:
	run_credits += 1
	AudioManager.play_sfx("coin_collect")
	_update_credits_display()

var _skip_used := false

func _debug_skip_wave() -> void:
	if not wave_active or _skip_used:
		return
	_skip_used = true
	wave_active = false
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
	boss_bar_container.visible = false
	for frag in get_tree().get_nodes_in_group("screen_fragments"):
		frag.queue_free()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	enemy_spawner.enemies_alive = 0
	wave_label.text = wave_manager.get_wave_name(current_wave) + " SKIPPED"
	wave_label.modulate.a = 1.0
	wave_label.visible = true
	await get_tree().create_timer(0.5).timeout
	_skip_used = false
	upgrade_select.show_upgrades(current_wave)
