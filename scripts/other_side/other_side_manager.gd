extends Node

## Orchestrator za "The Other Side" borbu.
## Wire-uje sve signale, kontrolise shrink, spawna fragmente, prati win/loss.

# ── Signali ───────────────────────────────────────────────────────────────────

signal shrink_started(duration: float)
signal shrink_stopped()
signal partner_died(ai_type: String)
signal other_side_won()
signal other_side_lost()

# ── Export ────────────────────────────────────────────────────────────────────

@export var shrink_duration: float = 6.0      # koliko traje jedan shrink (s)
@export var shrink_rate: float = 10.0         # % po sekundi za overlay
@export var fragments_per_ai: int = 3         # koliko fragmenata po AI igracu
@export var fragment_restore: float = 25.0    # % koji fragment vraca
@export var fragment_spread: float = 120.0    # radius spawna fragmenata

# ── Reference (podesiti u sceni) ──────────────────────────────────────────────

@onready var player_boss: CharacterBody2D = $"../PlayerBoss"
@onready var light_ai: CharacterBody2D = $"../AILight"
@onready var heavy_ai: CharacterBody2D = $"../AIHeavy"
@onready var enemy_spawner = $"../EnemySpawner"
@onready var hud = $"../HUD/OtherSideHUD"

var fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

# ── Stanje ────────────────────────────────────────────────────────────────────

var shrink_active: bool = false
var _light_dead: bool = false
var _heavy_dead: bool = false

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	_connect_signals()


func _process(delta: float) -> void:
	if not shrink_active:
		return
	# Shrink AI overlaye svaki frame
	_tick_ai_overlay(light_ai, delta)
	_tick_ai_overlay(heavy_ai, delta)

# ── Signal connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	# Player boss
	player_boss.shrink_activated.connect(_on_shrink_activated)
	player_boss.wave_summoned.connect(_on_wave_summoned)
	player_boss.boss_damaged.connect(_on_boss_damaged)
	player_boss.phase_changed.connect(_on_phase_changed)

	# AI igraci
	light_ai.ai_died.connect(_on_ai_died)
	light_ai.ai_damaged.connect(_on_ai_damaged)
	light_ai.emp_hit_boss.connect(_on_emp_hit_boss)
	light_ai.fragment_collected.connect(_on_fragment_collected)

	heavy_ai.ai_died.connect(_on_ai_died)
	heavy_ai.ai_damaged.connect(_on_ai_damaged)
	heavy_ai.emp_hit_boss.connect(_on_emp_hit_boss)
	heavy_ai.fragment_collected.connect(_on_fragment_collected)

	# Manager signali ka AI igracima
	shrink_started.connect(light_ai.enter_panic_mode.unbind(1))
	shrink_started.connect(heavy_ai.enter_panic_mode.unbind(1))
	shrink_stopped.connect(light_ai.exit_panic_mode)
	shrink_stopped.connect(heavy_ai.exit_panic_mode)

	partner_died.connect(light_ai.enter_berserk.unbind(1))
	partner_died.connect(heavy_ai.enter_berserk.unbind(1))

# ── Shrink ────────────────────────────────────────────────────────────────────

func _on_shrink_activated() -> void:
	if shrink_active:
		return
	shrink_active = true
	shrink_started.emit(shrink_duration)

	_spawn_fragments_near(light_ai)
	_spawn_fragments_near(heavy_ai)

	await get_tree().create_timer(shrink_duration).timeout
	shrink_active = false
	shrink_stopped.emit()


func _tick_ai_overlay(ai: CharacterBody2D, delta: float) -> void:
	if not is_instance_valid(ai):
		return
	var overlay = ai.get_node_or_null("AIScreenOverlay")
	if overlay and overlay.has_method("apply_shrink"):
		overlay.apply_shrink(shrink_rate, delta)

# ── Fragment spawn ────────────────────────────────────────────────────────────

func _spawn_fragments_near(ai: CharacterBody2D) -> void:
	if not is_instance_valid(ai):
		return
	for i in fragments_per_ai:
		var frag = fragment_scene.instantiate()
		var angle := randf() * TAU
		var dist := randf_range(60.0, fragment_spread)
		frag.global_position = ai.global_position + Vector2(cos(angle), sin(angle)) * dist
		frag.restore_value = fragment_restore
		frag.add_to_group("other_side_fragments")
		# Fragment ne treba da poziva screen_closing.restore — manager hvata collected signal
		frag.collected.connect(_on_fragment_auto_collected)
		get_tree().current_scene.add_child(frag)

# ── Signal handlers ───────────────────────────────────────────────────────────

func _on_fragment_auto_collected(_value: float) -> void:
	# Fragment je skupio NEKO — AI igrac ce sam da pozove overlay.restore
	# kroz _on_fragment_body_entered u ai_player.gd
	pass


func _on_fragment_collected(ai_type: String) -> void:
	if hud and hud.has_method("update_screen_percent"):
		var ai := light_ai if ai_type == "light" else heavy_ai
		var overlay = ai.get_node_or_null("AIScreenOverlay")
		if overlay:
			hud.update_screen_percent(ai_type, overlay.get_screen_percent())


func _on_emp_hit_boss() -> void:
	if player_boss and player_boss.has_method("apply_emp_debuff"):
		player_boss.apply_emp_debuff()
	if hud and hud.has_method("flash_emp_warning"):
		hud.flash_emp_warning()


func _on_boss_damaged(current_hp: int, max_hp: int) -> void:
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(current_hp, max_hp)
	if current_hp <= 0:
		_on_boss_died()


func _on_boss_died() -> void:
	other_side_lost.emit()
	# TODO: prikazati game over screen sa porukom "The boss has fallen."


func _on_phase_changed(phase: int) -> void:
	if hud and hud.has_method("show_phase"):
		hud.show_phase(phase)


func _on_ai_damaged(current_hp: int, max_hp: int, ai_type: String) -> void:
	if hud and hud.has_method("update_ai_hp"):
		hud.update_ai_hp(ai_type, current_hp, max_hp)


func _on_ai_died(ai_type: String) -> void:
	if ai_type == "light":
		_light_dead = true
		if is_instance_valid(heavy_ai):
			partner_died.emit("light")
	else:
		_heavy_dead = true
		if is_instance_valid(light_ai):
			partner_died.emit("heavy")
	_check_win()


func _check_win() -> void:
	if _light_dead and _heavy_dead:
		other_side_won.emit()
		# TODO: prikazati win screen sa porukom "You are the boss."

# ── Summon wave ───────────────────────────────────────────────────────────────

func _on_wave_summoned() -> void:
	if not enemy_spawner:
		return
	var queue := [{"type": "pixel_grunt", "count": 4, "delay": 0.0}]
	if enemy_spawner.has_method("add_spawning"):
		enemy_spawner.add_spawning(queue)
