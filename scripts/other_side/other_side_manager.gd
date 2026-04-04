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
@export var light_spawn_offset: Vector2 = Vector2(260, -40)
@export var heavy_spawn_offset: Vector2 = Vector2(260, 80)
@export var lose_title: String = "YOU LOST"
@export var lose_subtitle: String = "The boss has fallen."
@export var win_title: String = "YOU WON"
@export var win_subtitle: String = "You are the boss."

# ── Reference (podesiti u sceni) ──────────────────────────────────────────────

@onready var player_boss: CharacterBody2D = $"../PlayerBoss"
@onready var light_ai: CharacterBody2D = $"../AILight"
@onready var heavy_ai: CharacterBody2D = $"../AIHeavy"
@onready var enemy_spawner = $"../EnemySpawner"
@onready var hud = $"../HUD/OtherSideHUD"
@onready var game_over_screen = $"../GameOver"
@onready var dungeon_map = $"../DungeonMap"

var fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

# ── Stanje ────────────────────────────────────────────────────────────────────

var shrink_active: bool = false
var _light_dead: bool = false
var _heavy_dead: bool = false
var _fight_ended: bool = false

# Score / Credits (preneseni iz prethodne faze)
var current_score: int = 0
var current_credits: int = 0

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("other_side_manager")
	current_score = SceneTransition.transfer_score
	current_credits = SceneTransition.transfer_credits
	_setup_scene()
	_connect_signals()
	_sync_hud_now()


func _process(delta: float) -> void:
	if _fight_ended:
		return
	if not shrink_active:
		_update_hud_cooldowns()
		return
	# Shrink AI overlaye svaki frame.
	if is_instance_valid(light_ai):
		_tick_ai_overlay(light_ai, delta)
	if is_instance_valid(heavy_ai):
		_tick_ai_overlay(heavy_ai, delta)
	_update_hud_cooldowns()

func _update_hud_cooldowns() -> void:
	if not hud or not player_boss:
		return
	if hud.has_method("update_shrink_cooldown") and player_boss.has_method("get_shrink_cooldown_percent"):
		hud.update_shrink_cooldown(player_boss.get_shrink_cooldown_percent())
	if hud.has_method("update_summon_cooldown") and player_boss.has_method("get_summon_cooldown_percent"):
		hud.update_summon_cooldown(player_boss.get_summon_cooldown_percent())


func _setup_scene() -> void:
	if dungeon_map and dungeon_map.has_method("generate"):
		dungeon_map.generate()
	var center := Vector2(640, 360)
	if dungeon_map and dungeon_map.has_method("get_player_spawn"):
		center = dungeon_map.get_player_spawn()
	if is_instance_valid(player_boss):
		player_boss.global_position = center
	if is_instance_valid(light_ai):
		light_ai.global_position = center + light_spawn_offset
	if is_instance_valid(heavy_ai):
		heavy_ai.global_position = center + heavy_spawn_offset

	if enemy_spawner:
		enemy_spawner.spawn_in_center = false
		enemy_spawner.center_position = center
		enemy_spawner.dungeon_map = dungeon_map
		if dungeon_map and dungeon_map.has_method("get_map_rect"):
			var local_rect: Rect2 = dungeon_map.get_map_rect()
			var world_rect := Rect2(local_rect.position + dungeon_map.global_position, local_rect.size)
			enemy_spawner.map_rect = world_rect

func _sync_hud_now() -> void:
	if not hud:
		return
	if hud.has_method("update_boss_hp") and player_boss:
		var boss_hp := int(player_boss.get("current_hp"))
		var boss_max := int(player_boss.get("max_hp"))
		if boss_max <= 0:
			boss_max = 1
		hud.update_boss_hp(boss_hp, boss_max)
	if hud.has_method("update_ai_hp") and light_ai:
		var light_hp := int(light_ai.get("current_hp"))
		var light_max := int(light_ai.get("max_hp"))
		if light_max <= 0:
			light_max = 1
		hud.update_ai_hp("light", light_hp, light_max)
	if hud.has_method("update_ai_hp") and heavy_ai:
		var heavy_hp := int(heavy_ai.get("current_hp"))
		var heavy_max := int(heavy_ai.get("max_hp"))
		if heavy_max <= 0:
			heavy_max = 1
		hud.update_ai_hp("heavy", heavy_hp, heavy_max)
	if hud.has_method("update_score"):
		hud.update_score(current_score)
	if hud.has_method("update_credits"):
		hud.update_credits(current_credits)

# ── Signal connections ────────────────────────────────────────────────────────

func _connect_signals() -> void:
	# Player boss
	if player_boss and player_boss.has_signal("shrink_activated"):
		player_boss.shrink_activated.connect(_on_shrink_activated)
	if player_boss and player_boss.has_signal("wave_summoned"):
		player_boss.wave_summoned.connect(_on_wave_summoned)
	if player_boss and player_boss.has_signal("boss_damaged"):
		player_boss.boss_damaged.connect(_on_boss_damaged)
	if player_boss and player_boss.has_signal("phase_changed"):
		player_boss.phase_changed.connect(_on_phase_changed)

	# AI igraci
	if light_ai and light_ai.has_signal("ai_died"):
		light_ai.ai_died.connect(_on_ai_died)
	if light_ai and light_ai.has_signal("ai_damaged"):
		light_ai.ai_damaged.connect(_on_ai_damaged)
	if light_ai and light_ai.has_signal("emp_hit_boss"):
		light_ai.emp_hit_boss.connect(_on_emp_hit_boss)
	if light_ai and light_ai.has_signal("fragment_collected"):
		light_ai.fragment_collected.connect(_on_fragment_collected)

	if heavy_ai and heavy_ai.has_signal("ai_died"):
		heavy_ai.ai_died.connect(_on_ai_died)
	if heavy_ai and heavy_ai.has_signal("ai_damaged"):
		heavy_ai.ai_damaged.connect(_on_ai_damaged)
	if heavy_ai and heavy_ai.has_signal("emp_hit_boss"):
		heavy_ai.emp_hit_boss.connect(_on_emp_hit_boss)
	if heavy_ai and heavy_ai.has_signal("fragment_collected"):
		heavy_ai.fragment_collected.connect(_on_fragment_collected)

	# Manager signali ka AI igracima
	if light_ai and light_ai.has_method("enter_panic_mode"):
		shrink_started.connect(light_ai.enter_panic_mode.unbind(1))
	if heavy_ai and heavy_ai.has_method("enter_panic_mode"):
		shrink_started.connect(heavy_ai.enter_panic_mode.unbind(1))
	if light_ai and light_ai.has_method("exit_panic_mode"):
		shrink_stopped.connect(light_ai.exit_panic_mode)
	if heavy_ai and heavy_ai.has_method("exit_panic_mode"):
		shrink_stopped.connect(heavy_ai.exit_panic_mode)

	if light_ai and light_ai.has_method("enter_berserk"):
		partner_died.connect(light_ai.enter_berserk.unbind(1))
	if heavy_ai and heavy_ai.has_method("enter_berserk"):
		partner_died.connect(heavy_ai.enter_berserk.unbind(1))

# ── Shrink ────────────────────────────────────────────────────────────────────

func _on_shrink_activated() -> void:
	if shrink_active:
		return
	shrink_active = true
	shrink_started.emit(shrink_duration)

	if is_instance_valid(light_ai):
		_spawn_fragments_near(light_ai)
	if is_instance_valid(heavy_ai):
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


func _on_fragment_collected(_ai_type: String) -> void:
	pass


func _on_emp_hit_boss() -> void:
	if player_boss and player_boss.has_method("apply_emp_debuff"):
		player_boss.apply_emp_debuff()


func _on_boss_damaged(current_hp: int, max_hp: int) -> void:
	if hud and hud.has_method("update_boss_hp"):
		hud.update_boss_hp(current_hp, max_hp)
	if current_hp <= 0:
		_on_boss_died()


func _on_boss_died() -> void:
	if _fight_ended:
		return
	_fight_ended = true
	shrink_active = false
	shrink_stopped.emit()
	other_side_lost.emit()
	SaveManager.update_high_score(current_score)
	SaveManager.add_credits(current_credits)
	if game_over_screen and game_over_screen.has_method("show_game_over"):
		game_over_screen.show_game_over(current_score, current_credits, lose_title, lose_subtitle)


func _on_phase_changed(_phase: int) -> void:
	pass


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
	if hud and hud.has_method("update_ai_hp"):
		hud.update_ai_hp(ai_type, 0, 1)
	_add_score(500)
	_add_credits(10)
	_check_win()


func _check_win() -> void:
	if _fight_ended:
		return
	if _light_dead and _heavy_dead:
		_fight_ended = true
		shrink_active = false
		shrink_stopped.emit()
		other_side_won.emit()
		SaveManager.update_high_score(current_score)
		SaveManager.add_credits(current_credits)
		if game_over_screen and game_over_screen.has_method("show_game_over"):
			game_over_screen.show_game_over(current_score, current_credits, win_title, win_subtitle, true)

# ── Summon wave ───────────────────────────────────────────────────────────────

func _on_wave_summoned() -> void:
	if not enemy_spawner:
		return
	var queue := [{"type": "pixel_grunt", "count": 4, "delay": 0.0}]
	if enemy_spawner.has_method("add_spawning"):
		enemy_spawner.add_spawning(queue)

# ── Score / Credits ──────────────────────────────────────────────────────────

func _add_score(amount: int) -> void:
	current_score += amount
	if hud and hud.has_method("update_score"):
		hud.update_score(current_score)


func _add_credits(amount: int) -> void:
	current_credits += amount
	if hud and hud.has_method("update_credits"):
		hud.update_credits(current_credits)
