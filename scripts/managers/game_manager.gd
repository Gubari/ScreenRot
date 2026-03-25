extends Node2D

@onready var player: CharacterBody2D = $Player
@onready var hud: CanvasLayer = $HUD
@onready var hp_label: Label = $HUD/HPLabel
@onready var score_label: Label = $HUD/ScoreLabel
@onready var defrag_bar: ProgressBar = $HUD/DefragBar
@onready var dash_bar: ProgressBar = $HUD/DashBar
@onready var multiplier_label: Label = $HUD/MultiplierLabel
@onready var debris_bar: ProgressBar = $HUD/DebrisBar
@onready var debris_label: Label = $HUD/DebrisLabel
@onready var enemy_spawner: Node2D = $EnemySpawner
@onready var wave_label: Label = $HUD/WaveLabel
@onready var credits_label: Label = $HUD/CreditsLabel
@onready var game_over_screen: CanvasLayer = $GameOver
@onready var upgrade_select: CanvasLayer = $UpgradeSelect
@onready var debris_overlay: CanvasLayer = $DebrisOverlay

var current_wave: int = 0
var wave_active: bool = false

var kills_this_wave: int = 0
var run_credits: int = 0

func _ready() -> void:
	player.player_damaged.connect(_on_player_damaged)
	player.score_changed.connect(_on_score_changed)
	player.player_died.connect(_on_player_died)
	player.defrag_activated.connect(_on_defrag_activated)
	enemy_spawner.all_enemies_dead.connect(_on_all_enemies_dead)
	enemy_spawner.enemy_killed_global.connect(_on_enemy_killed)
	upgrade_select.upgrade_chosen.connect(_on_upgrade_chosen)
	if debris_overlay and debris_overlay.has_signal("debris_changed"):
		debris_overlay.debris_changed.connect(_on_debris_changed)
	update_hud()
	AudioManager.play_music("gameplay")
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _process(_delta: float) -> void:
	defrag_bar.value = player.get_defrag_percent() * 100.0
	dash_bar.value = player.get_dash_percent() * 100.0
	if OS.is_debug_build() and Input.is_key_pressed(KEY_U):
		_debug_skip_wave()

func start_next_wave() -> void:
	current_wave += 1
	wave_active = true
	kills_this_wave = 0
	wave_label.text = "WAVE " + str(current_wave)
	wave_label.visible = true
	wave_label.modulate.a = 1.0

	var tween = create_tween()
	tween.tween_property(wave_label, "modulate:a", 0.0, 1.5).set_delay(1.0)

	var queue: Array = get_wave_data(current_wave)
	enemy_spawner.start_spawning(queue)

func get_wave_data(wave: int) -> Array:
	match wave:
		1:
			return [
				{"type": "pixel_grunt", "count": 3, "delay": 0.0},
				{"type": "pixel_grunt", "count": 2, "delay": 3.0},
				{"type": "static_walker", "count": 2, "delay": 4.0},
				{"type": "bit_bug", "count": 3, "delay": 3.0},
				{"type": "pixel_grunt", "count": 4, "delay": 4.0},
				{"type": "static_walker", "count": 2, "delay": 3.0},
				{"type": "bit_bug", "count": 5, "delay": 3.0},
				{"type": "pixel_grunt", "count": 8, "delay": 4.0},
				{"type": "static_walker", "count": 2, "delay": 2.0},
				{"type": "bit_bug", "count": 5, "delay": 2.0},
				{"type": "pixel_grunt", "count": 4, "delay": 2.0},
			]
		_:
			return [
				{"type": "pixel_grunt", "count": 5, "delay": 0.0},
				{"type": "static_walker", "count": 3, "delay": 3.0},
				{"type": "bit_bug", "count": 5, "delay": 3.0},
			]

func _on_enemy_killed(pos: Vector2, type: String) -> void:
	kills_this_wave += 1
	run_credits += 1
	if debris_overlay and debris_overlay.has_method("add_debris"):
		debris_overlay.add_debris(pos, type)
	update_debris_display()
	update_multiplier()
	_update_credits_display()

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
	wave_label.text = "WAVE " + str(current_wave) + " CLEARED!"
	wave_label.modulate.a = 1.0
	wave_label.visible = true
	run_credits += 10
	AudioManager.play_sfx("wave_clear")
	_update_credits_display()

	await get_tree().create_timer(1.5).timeout
	upgrade_select.show_upgrades(current_wave)

func _on_upgrade_chosen(_upgrade_id: String) -> void:
	# TODO: apply upgrade effects to player here
	start_next_wave()

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
	wave_active = false
	SaveManager.add_credits(run_credits)
	SaveManager.update_high_score(final_score)
	game_over_screen.show_game_over(final_score, run_credits)

func _update_credits_display() -> void:
	credits_label.text = "Credits: " + str(run_credits)

func _on_defrag_activated() -> void:
	if debris_overlay and debris_overlay.has_method("defrag_clear"):
		debris_overlay.defrag_clear()
	update_debris_display()
	update_multiplier()

var _skip_used := false

func _debug_skip_wave() -> void:
	if not wave_active or _skip_used:
		return
	_skip_used = true
	wave_active = false
	enemy_spawner.spawning = false
	enemy_spawner.spawn_queue.clear()
	for enemy in get_tree().get_nodes_in_group("enemies"):
		enemy.queue_free()
	enemy_spawner.enemies_alive = 0
	wave_label.text = "WAVE " + str(current_wave) + " SKIPPED"
	wave_label.modulate.a = 1.0
	wave_label.visible = true
	await get_tree().create_timer(0.5).timeout
	_skip_used = false
	upgrade_select.show_upgrades(current_wave)
