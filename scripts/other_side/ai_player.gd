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
@export var bullet_scene_path: String = "res://scenes/player/bullet.tscn"

@export var has_dash: bool = true
@export var dash_speed: float = 500.0
@export var dash_duration: float = 0.12
@export var dash_cooldown: float = 3.0

@export var emp_cooldown: float = 12.0
@export var emp_radius: float = 200.0
@export var emp_windup: float = 0.8
@export var overlay_frame_size: Vector2 = Vector2(1280.0, 720.0)

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
var _base_fire_rate: float = 0.0

# Berserk
var is_berserk: bool = false

# Shield (Heavy)
var is_shielded: bool = false
var _last_shield_threshold: float = 1.0

# Dash state
var _is_dashing: bool = false
var _dash_timer: float = 0.0
var _dash_dir: Vector2 = Vector2.ZERO

# Navigation
const NAV_UPDATE_INTERVAL: float = 0.15
var _nav_update_timer: float = 0.0
var nav_agent: NavigationAgent2D = null
var boss: Node2D = null

# Overlay & Sprite
var overlay: Node2D = null
var sprite: AnimatedSprite2D = null
var _color_tween: Tween = null

# Bullet scena je podesiva po AI varijanti (light/heavy).
var bullet_scene: PackedScene

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_hp = max_hp
	_base_fire_rate = fire_rate
	add_to_group("ai_players")
	add_to_group("player")
	bullet_scene = load(bullet_scene_path) as PackedScene
	if bullet_scene == null:
		bullet_scene = preload("res://scenes/player/bullet.tscn")

	collision_layer = 1    # player layer — fragmenti (Area2D mask=1) detektuju AI
	collision_mask = 18    # enemies (2) + terrain (5)

	nav_agent = NavigationAgent2D.new()
	nav_agent.path_desired_distance = 6.0
	nav_agent.target_desired_distance = 6.0
	nav_agent.radius = 35.0
	nav_agent.avoidance_enabled = true
	nav_agent.max_speed = maxf(MovementFormula.scalar(move_speed), 1.0)
	nav_agent.velocity_computed.connect(_on_velocity_computed)
	add_child(nav_agent)

	overlay = get_node_or_null("AIScreenOverlay")
	if overlay:
		overlay.set("frame_size", overlay_frame_size)
		# Keep overlay viewport size visually identical for light/heavy,
		# independent of parent (AI) scene scale.
		if absf(scale.x) > 0.0001 and absf(scale.y) > 0.0001:
			overlay.scale = Vector2(1.0 / scale.x, 1.0 / scale.y)
		overlay.queue_redraw()
	sprite = get_node_or_null("Sprite") as AnimatedSprite2D

	await get_tree().process_frame
	var bosses := get_tree().get_nodes_in_group("player_boss")
	if bosses.size() > 0:
		boss = bosses[0]
		# Boss mora biti u "enemies" grupi da bi bullet.tscn (laser) mogao da ga pogodi
		if boss and not boss.is_in_group("enemies"):
			boss.add_to_group("enemies")
		# Boss mora imati layer 2 bit da bullet.tscn (mask=2) fizicki detektuje
		if boss and boss is CollisionObject2D:
			boss.collision_layer = boss.collision_layer | 2


func _physics_process(delta: float) -> void:
	if is_dying:
		return
	_tick_timers(delta)
	_update_state()
	_execute_state(delta)
	move_and_slide()
	_update_animation()

# ── Timeri ────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	fire_timer = maxf(fire_timer - delta, 0.0)
	emp_timer = maxf(emp_timer - delta, 0.0)
	dash_cooldown_timer = maxf(dash_cooldown_timer - delta, 0.0)

	if _is_dashing:
		_dash_timer -= delta
		if _dash_timer <= 0.0:
			_is_dashing = false

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
		current_state = State.CHASE
		return

	if current_state == State.EMP_WINDUP:
		return

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
			_emp_windup_visual()
		State.SHIELDED:
			_do_chase(delta)

# ── Kretanje ─────────────────────────────────────────────────────────────────

func _do_chase(delta: float) -> void:
	if _is_dashing:
		velocity = _dash_dir * dash_speed
		return

	if not boss or not is_instance_valid(boss):
		velocity = Vector2.ZERO
		return

	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		nav_agent.target_position = boss.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var dir := (nav_agent.get_next_path_position() - global_position).normalized()
	var spd := move_speed * (1.5 if is_berserk else 1.0)
	var desired := MovementFormula.velocity(dir, spd)
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired)
	else:
		velocity = desired

	# Dash prema bossu kad je dovoljno daleko
	if has_dash and not _is_dashing and dash_cooldown_timer <= 0.0:
		var dist := global_position.distance_to(boss.global_position)
		if dist > 150.0:
			_start_dash(dir)


func _do_collect(delta: float) -> void:
	var frag := _find_nearest_fragment()
	if not frag:
		current_state = State.CHASE
		return

	_nav_update_timer -= delta
	if _nav_update_timer <= 0.0:
		_nav_update_timer = NAV_UPDATE_INTERVAL
		nav_agent.target_position = frag.global_position

	if nav_agent.is_navigation_finished():
		velocity = Vector2.ZERO
		return

	var dir := (nav_agent.get_next_path_position() - global_position).normalized()
	var desired := MovementFormula.velocity(dir, move_speed)
	if nav_agent.avoidance_enabled:
		nav_agent.set_velocity(desired)
	else:
		velocity = desired


func _on_velocity_computed(safe_velocity: Vector2) -> void:
	velocity = safe_velocity


func _update_animation() -> void:
	if not sprite:
		return
	if velocity.length_squared() > 10.0:
		if sprite.animation != &"run":
			sprite.play(&"run")
		# Flip na osnovu smera kretanja
		sprite.flip_h = velocity.x < 0
	else:
		if sprite.animation != &"idle":
			sprite.play(&"idle")
		# Flip ka bossu
		if boss and is_instance_valid(boss):
			sprite.flip_h = boss.global_position.x < global_position.x


func _get_base_color() -> Color:
	if is_berserk:
		return Color(1.2, 0.4, 0.4, 1.0)
	if is_shielded:
		return Color(0.6, 0.8, 1.2, 1.0)
	return Color.WHITE


func _flash_color(flash: Color, duration: float = 0.15) -> void:
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	modulate = flash
	_color_tween = create_tween()
	_color_tween.tween_property(self, "modulate", _get_base_color(), duration)


func _start_dash(dir: Vector2) -> void:
	_is_dashing = true
	_dash_timer = dash_duration
	_dash_dir = dir
	dash_cooldown_timer = dash_cooldown * (0.5 if is_berserk else 1.0)
	_flash_color(Color(1.5, 1.5, 1.5, 1.0), 0.1)

# ── Pucanje ───────────────────────────────────────────────────────────────────

func _try_shoot() -> void:
	if fire_timer > 0.0 or not boss or not is_instance_valid(boss):
		return
	_shoot()
	fire_timer = fire_rate * (2.0 if panic_mode else 1.0)


func _shoot() -> void:
	if not boss or not is_instance_valid(boss):
		return
	var bullet = bullet_scene.instantiate()
	var dir := (boss.global_position - global_position).normalized()
	bullet.global_position = global_position
	bullet.direction = dir
	bullet.rotation = dir.angle()
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	get_tree().current_scene.add_child(bullet)

# ── EMP ───────────────────────────────────────────────────────────────────────

func _boss_in_emp_range() -> bool:
	if not boss or not is_instance_valid(boss):
		return false
	return global_position.distance_to(boss.global_position) <= emp_radius


func _trigger_emp() -> void:
	current_state = State.CHASE
	if _boss_in_emp_range():
		emp_hit_boss.emit()
	_flash_color(Color(1.0, 0.6, 0.0, 1.0), 0.4)


func _emp_windup_visual() -> void:
	var t := fmod(Time.get_ticks_msec() * 0.01, 1.0)
	modulate = Color(1.0 + t * 0.3, 0.5 - t * 0.3, 0.0, 1.0)



# ── Panic mode (shrink) ───────────────────────────────────────────────────────

func enter_panic_mode() -> void:
	panic_mode = true


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


## screen_fragment.gd poziva ovo direktno kad AI igrac ga dodirne.
func _on_fragment_body_entered(_fragment: Node2D) -> void:
	if overlay:
		overlay.restore(25.0)
	fragment_collected.emit(ai_type)

# ── Berserk ───────────────────────────────────────────────────────────────────

func enter_berserk() -> void:
	if is_berserk:
		return
	is_berserk = true
	move_speed *= 1.5
	fire_rate *= 0.6
	if ai_type == "light" and has_dash:
		dash_cooldown *= 0.5
	_flash_color(Color(1.5, 0.2, 0.2, 1.0), 0.3)

# ── Heavy Shield ─────────────────────────────────────────────────────────────

func _check_shield_trigger() -> void:
	if not has_shield:
		return
	var pct := float(current_hp) / float(max_hp)
	for threshold in [0.75, 0.50, 0.25]:
		if pct <= threshold and _last_shield_threshold > threshold:
			_last_shield_threshold = threshold
			_activate_shield()
			break


func _activate_shield() -> void:
	if is_shielded:
		return
	is_shielded = true
	_flash_color(Color(0.4, 0.6, 1.5, 1.0), 0.2)
	await get_tree().create_timer(3.0).timeout
	if is_instance_valid(self):
		is_shielded = false
		modulate = _get_base_color()

# ── Damage / Smrt ─────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if is_shielded or is_dying:
		_flash_color(Color(0.4, 0.6, 1.5, 1.0), 0.15)
		return
	current_hp -= amount
	current_hp = maxi(current_hp, 0)
	ai_damaged.emit(current_hp, max_hp, ai_type)
	_check_shield_trigger()

	if current_hp <= 0:
		die()
		return

	_flash_color(Color(1.8, 1.8, 1.8, 1.0), 0.12)


func die() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	ai_died.emit(ai_type)
	if _color_tween and _color_tween.is_valid():
		_color_tween.kill()
	var death_tw := create_tween()
	death_tw.tween_property(self, "modulate", Color(1.0, 1.0, 1.0, 0.0), 0.4)
	await death_tw.finished
	if is_instance_valid(self):
		queue_free()
