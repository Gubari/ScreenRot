extends CharacterBody2D

## AI igrac koji lovi player_boss u "The Other Side" borbi.
## Postoje dve varijante (razlikuju se export vrednostima u scenama):
##   ai_light.tscn  — brz, agresivan, nisko HP, ima dash
##   ai_heavy.tscn  — spor, visoko HP, nema dash, ima shield faze

# ── Signali ───────────────────────────────────────────────────────────────────

signal ai_died(ai_type: String)
signal ai_damaged(current_hp: int, max_hp: int, ai_type: String)
signal emp_hit_boss()
signal fragment_collected(ai_type: String)

# ── Export (razlikuju se u Light i Heavy sceni) ───────────────────────────────

@export var ai_type: String = "light"   # "light" ili "heavy"
@export var max_hp: int = 8
@export var move_speed: float = 180.0
@export var fire_rate: float = 0.4
@export var bullet_damage: int = 1
@export var bullet_speed: float = 500.0

@export var has_dash: bool = true
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 3.0

@export var emp_cooldown: float = 12.0
@export var emp_radius: float = 200.0
@export var emp_windup: float = 0.8

@export var has_shield: bool = false         # samo Heavy
@export var shield_hp_threshold: float = 0.25

# ── Stanje ────────────────────────────────────────────────────────────────────

enum State { CHASE, SHOOT, COLLECT, EMP_WINDUP, SHIELDED }

var current_state: State = State.CHASE
var current_hp: int
var is_dying: bool = false

# Timeri
var fire_timer: float = 0.0
var emp_timer: float = 0.0
var dash_timer: float = 0.0
var dash_cooldown_timer: float = 0.0
var emp_windup_timer: float = 0.0

# Panic mode (shrink aktivan)
var panic_mode: bool = false
var _base_fire_rate: float = 0.0  # cuva originalni fire_rate

# Berserk
var is_berserk: bool = false

# Shield (Heavy)
var is_shielded: bool = false
var _shield_triggers_remaining: int = 3  # na 75%, 50%, 25%
var _last_shield_threshold: float = 1.0

# Navigation
var nav_agent: NavigationAgent2D = null
var boss: Node2D = null

# Overlay
var overlay: Node2D = null  # ai_screen_overlay child node

# Reference scene
var bullet_scene: PackedScene = preload("res://scenes/player/bullet.tscn")

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_hp = max_hp
	_base_fire_rate = fire_rate
	add_to_group("ai_players")

	# NavigationAgent2D setup (isti pattern kao enemy_base.gd)
	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	nav_agent.radius = 35.0
	nav_agent.avoidance_enabled = true
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(nav_agent)

	# Pronaci overlay child
	overlay = get_node_or_null("AIScreenOverlay")

	await get_tree().process_frame
	# Pronaci player_boss
	var bosses := get_tree().get_nodes_in_group("player_boss")
	if bosses.size() > 0:
		boss = bosses[0]


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_tick_timers(delta)
	_update_state()
	_execute_state(delta)
	move_and_slide()

# ── Timeri ────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	fire_timer = maxf(fire_timer - delta, 0.0)
	emp_timer = maxf(emp_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if current_state == State.EMP_WINDUP:
		emp_windup_timer -= delta
		if emp_windup_timer <= 0.0:
			_trigger_emp()

# ── State machine ─────────────────────────────────────────────────────────────

func _update_state() -> void:
	if is_shielded:
		current_state = State.SHIELDED
		return

	if panic_mode:
		var frag := _find_nearest_fragment()
		if frag:
			current_state = State.COLLECT
			return
		# Nema fragmenata — nastavi normalno
		current_state = State.CHASE
		return

	if current_state == State.EMP_WINDUP:
		return  # ne prekidaj windup

	# Pokusaj EMP ako je cooldown prosao i boss je blizu
	if emp_timer <= 0.0 and _boss_in_emp_range():
		current_state = State.EMP_WINDUP
		emp_windup_timer = emp_windup
		emp_timer = emp_cooldown
		return

	current_state = State.CHASE


func _execute_state(delta: float) -> void:
	match current_state:
		State.CHASE:
			_do_chase(delta)
			_try_shoot()
		State.SHOOT:
			velocity = Vector2.ZERO
			_try_shoot()
		State.COLLECT:
			_do_collect(delta)
		State.EMP_WINDUP:
			velocity = Vector2.ZERO
			# TODO: vizuelni telegraphing (npr. treperi narandzasto)
		State.SHIELDED:
			_do_chase(delta)  # nastavi da se krece dok je shield aktivan

# ── Kretanje ─────────────────────────────────────────────────────────────────

func _do_chase(delta: float) -> void:
	# TODO: NavigationAgent2D ka boss poziciji (pogledati enemy_base.gd do_movement)
	pass


func _do_collect(delta: float) -> void:
	var frag := _find_nearest_fragment()
	if not frag:
		current_state = State.CHASE
		return
	# TODO: NavigationAgent2D ka fragment poziciji
	pass


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity

# ── Pucanje ───────────────────────────────────────────────────────────────────

func _try_shoot() -> void:
	if fire_timer > 0.0 or not boss or not is_instance_valid(boss):
		return
	_shoot()
	# U panic modu puca duplo sporije
	fire_timer = fire_rate * (2.0 if panic_mode else 1.0)


func _shoot() -> void:
	# TODO: spawna bullet ka boss poziciji (pogledati player.gd shoot)
	pass

# ── EMP ───────────────────────────────────────────────────────────────────────

func _boss_in_emp_range() -> bool:
	if not boss or not is_instance_valid(boss):
		return false
	return global_position.distance_to(boss.global_position) <= emp_radius


func _trigger_emp() -> void:
	current_state = State.CHASE
	if _boss_in_emp_range():
		emp_hit_boss.emit()
		# TODO: vizuelni efekat — beli krug koji se siri


# ── Panic mode (shrink) ───────────────────────────────────────────────────────

## Poziva other_side_manager kad shrink_started signal stigne.
func enter_panic_mode() -> void:
	panic_mode = true


## Poziva other_side_manager kad shrink_stopped signal stigne.
func exit_panic_mode() -> void:
	panic_mode = false
	if current_state == State.COLLECT:
		current_state = State.CHASE


func _find_nearest_fragment() -> Node2D:
	var frags := get_tree().get_nodes_in_group("other_side_fragments")
	var nearest: Node2D = null
	var nearest_dist := INF
	for f in frags:
		if not (f is Node2D):
			continue
		var d := global_position.distance_to((f as Node2D).global_position)
		if d < nearest_dist:
			nearest_dist = d
			nearest = f as Node2D
	return nearest


## Poziva se kad AI igrac touchuje fragment (Area2D signal).
func _on_fragment_body_entered(_fragment: Node2D) -> void:
	if overlay:
		overlay.restore(25.0)
	fragment_collected.emit(ai_type)

# ── Berserk ───────────────────────────────────────────────────────────────────

## Poziva other_side_manager kad partner umre.
func enter_berserk() -> void:
	if is_berserk:
		return
	is_berserk = true
	move_speed *= 1.5
	fire_rate *= 0.6
	if ai_type == "light" and has_dash:
		dash_cooldown *= 0.5
	# TODO: vizuelni efekat — crveni tint koji ostaje

# ── Heavy Shield ─────────────────────────────────────────────────────────────

func _check_shield_trigger() -> void:
	if not has_shield:
		return
	var pct := float(current_hp) / float(max_hp)
	# Proveri pragove: 75%, 50%, 25%
	for threshold in [0.75, 0.50, 0.25]:
		if pct <= threshold and _last_shield_threshold > threshold:
			_last_shield_threshold = threshold
			_activate_shield()
			break


func _activate_shield() -> void:
	if is_shielded:
		return
	is_shielded = true
	# TODO: plavi flash (pogledati boss_base.gd flash_immune)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		is_shielded = false

# ── Damage / Smrt ─────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_shielded or is_dying:
		# TODO: flash immune efekat
		return
	current_hp -= amount
	current_hp = maxi(current_hp, 0)
	ai_damaged.emit(current_hp, max_hp, ai_type)
	_check_shield_trigger()

	if current_hp <= 0:
		die()
		return

	# TODO: flash white


func die() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	ai_died.emit(ai_type)
	# TODO: death animacija pa queue_free
	queue_free()
