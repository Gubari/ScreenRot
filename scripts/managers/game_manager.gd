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
@onready var game_over_screen: CanvasLayer = $GameOver

var current_wave: int = 0
var wave_active: bool = false

# Debris tracking (placeholder until real debris system)
var debris_percent: float = 0.0
var kills_this_wave: int = 0

func _ready() -> void:
	player.player_damaged.connect(_on_player_damaged)
	player.score_changed.connect(_on_score_changed)
	player.player_died.connect(_on_player_died)
	player.defrag_activated.connect(_on_defrag_activated)
	enemy_spawner.all_enemies_dead.connect(_on_all_enemies_dead)
	enemy_spawner.enemy_killed_global.connect(_on_enemy_killed)
	update_hud()
	await get_tree().create_timer(1.0).timeout
	start_next_wave()

func _process(_delta: float) -> void:
	defrag_bar.value = player.get_defrag_percent() * 100.0
	dash_bar.value = player.get_dash_percent() * 100.0

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

func _on_enemy_killed(_pos: Vector2, type: String) -> void:
	kills_this_wave += 1
	var debris_per_kill := 2.5
	if type == "static_walker":
		debris_per_kill = 4.0
	debris_percent = min(debris_percent + debris_per_kill, 100.0)
	update_debris_display()
	update_multiplier()

func update_multiplier() -> void:
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

func _on_all_enemies_dead() -> void:
	if not wave_active:
		return
	wave_active = false
	wave_label.text = "WAVE " + str(current_wave) + " CLEARED!"
	wave_label.modulate.a = 1.0
	wave_label.visible = true

	await get_tree().create_timer(2.0).timeout
	start_next_wave()

func update_hud() -> void:
	hp_label.text = "HP: " + str(player.current_hp) + "/" + str(player.max_hp)
	score_label.text = "Score: " + str(player.score)
	multiplier_label.text = "x" + str(player.multiplier)
	debris_bar.value = 0
	debris_label.text = "CLEAN"

func _on_player_damaged(current_hp: int) -> void:
	hp_label.text = "HP: " + str(current_hp) + "/" + str(player.max_hp)

func _on_score_changed(score: int, multiplier: int) -> void:
	score_label.text = "Score: " + str(score)
	multiplier_label.text = "x" + str(multiplier)

func _on_player_died(final_score: int, credits: int) -> void:
	wave_active = false
	game_over_screen.show_game_over(final_score, credits)

func _on_defrag_activated() -> void:
	debris_percent = 0.0
	update_debris_display()
	update_multiplier()
