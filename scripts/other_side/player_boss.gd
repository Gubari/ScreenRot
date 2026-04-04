extends CharacterBody2D

## Igrač kontroliše Anihilatora u "The Other Side" borbi.
##
## Kontrole:
##   WASD        — kretanje
##   Levi klik   — pucanje (spread po fazi)
##   Space       — Screen Shrink ability (cooldown po fazi)
##   Shift       — Summon minion wave (cooldown 18s)

# ── Signali ───────────────────────────────────────────────────────────────────

signal boss_damaged(current_hp: int, max_hp: int)
signal phase_changed(phase: int)    # 1, 2 ili 3
signal shrink_activated()           # Space pritisnut i cooldown prosao
signal wave_summoned()              # Shift pritisnut i cooldown prosao

# ── Export varijable ──────────────────────────────────────────────────────────

@export var max_hp: int = 25
@export var move_speed: float = 130.0
@export var bullet_speed: float = 600.0
@export var bullet_damage: int = 2
@export var camera_zoom: Vector2 = Vector2(1.0, 1.0)

# Spread konfiguracija po fazi
@export var p2_spread_count: int = 3
@export var p2_spread_angle: float = 45.0
@export var p3_spread_count: int = 5
@export var p3_spread_angle: float = 60.0

# Fire rate po fazi (sekunde između hitaca)
@export var p1_fire_rate: float = 0.9
@export var p2_fire_rate: float = 0.75
@export var p3_fire_rate: float = 0.55

# Pragovi za faze (procenat HP)
@export var phase2_threshold: float = 0.6
@export var phase3_threshold: float = 0.3

# Cooldowni po fazi (sekunde)
@export var p1_shrink_cooldown: float = 20.0
@export var p2_shrink_cooldown: float = 15.0
@export var p3_shrink_cooldown: float = 10.0
@export var summon_cooldown_max: float = 18.0

# Invincibility posle primljenog damage-a
@export var invincible_duration: float = 1.2

# ── Stanje ────────────────────────────────────────────────────────────────────

var current_hp: int
var current_phase: int = 1
var fire_timer: float = 0.0
var fire_rate: float = 0.9
var shoot_anim_timer: float = 0.0

var shrink_cooldown_timer: float = 0.0
var shrink_cooldown_max: float = 20.0

var summon_cooldown_timer: float = 0.0

var invincible: bool = false
var invincible_timer: float = 0.0

# EMP debuff (postavlja manager kad ai_player emituje emp_hit_boss)
var debuff_active: bool = false
var debuff_timer: float = 0.0
const EMP_DEBUFF_DURATION: float = 3.0
const EMP_FIRE_RATE_MULT: float = 2.0
const EMP_SPEED_MULT: float = 0.7

# ── Reference ─────────────────────────────────────────────────────────────────

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var outline_sprite: AnimatedSprite2D = $Outline
@onready var legs_sprite: AnimatedSprite2D = $Legs
@onready var outline_legs_sprite: AnimatedSprite2D = $OutlineLegs
@onready var camera: Camera2D = $Camera2D
var bullet_scene: PackedScene = preload("res://scenes/enemies/boss_bullet.tscn")
const OUTLINE_BASE_COLOR := Color(0, 0, 0, 0.75)

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	current_hp = max_hp
	add_to_group("player_boss")
	fire_rate = p1_fire_rate
	shrink_cooldown_max = p1_shrink_cooldown
	if camera:
		camera.zoom = camera_zoom


func _physics_process(delta: float) -> void:
	_tick_timers(delta)
	_handle_movement()
	_handle_rotation()
	_handle_shooting(delta)
	_update_animation_state(delta)
	_handle_abilities()
	_handle_invincibility(delta)
	move_and_slide()
	var hud = get_tree().get_first_node_in_group("other_side_hud")
	if hud:
		hud.update_shrink_cooldown(get_shrink_cooldown_percent())
		hud.update_summon_cooldown(get_summon_cooldown_percent())


# ── Timeri ────────────────────────────────────────────────────────────────────

func _tick_timers(delta: float) -> void:
	shrink_cooldown_timer = maxf(shrink_cooldown_timer - delta, 0.0)
	summon_cooldown_timer = maxf(summon_cooldown_timer - delta, 0.0)
	shoot_anim_timer = maxf(shoot_anim_timer - delta, 0.0)

	if debuff_active:
		debuff_timer -= delta
		if debuff_timer <= 0.0:
			debuff_active = false

# ── Kretanje ─────────────────────────────────────────────────────────────────

func _handle_movement() -> void:
	var input_dir := Vector2(
		Input.get_axis("move_left", "move_right"),
		Input.get_axis("move_up", "move_down")
	).normalized()
	var effective_speed := move_speed * (EMP_SPEED_MULT if debuff_active else 1.0)
	velocity = MovementFormula.velocity(input_dir, effective_speed)


func _handle_rotation() -> void:
	var mouse_pos := get_global_mouse_position()
	var facing_left := mouse_pos.x < global_position.x
	if sprite:
		sprite.flip_h = facing_left
	if outline_sprite:
		outline_sprite.flip_h = facing_left
	if legs_sprite:
		legs_sprite.flip_h = facing_left
	if outline_legs_sprite:
		outline_legs_sprite.flip_h = facing_left

# ── Pucanje ───────────────────────────────────────────────────────────────────

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	if fire_timer < 0.0:
		fire_timer = 0.0

	if Input.is_action_pressed("shoot") and fire_timer <= 0.0:
		_shoot()
		var effective_rate := fire_rate * (EMP_FIRE_RATE_MULT if debuff_active else 1.0)
		fire_timer = effective_rate
		shoot_anim_timer = minf(effective_rate * 0.75, 0.18)


func _shoot() -> void:
	match current_phase:
		1: _shoot_single()
		2: _shoot_spread(p2_spread_count, p2_spread_angle)
		3: _shoot_spread(p3_spread_count, p3_spread_angle)


func _shoot_single() -> void:
	var dir := (get_global_mouse_position() - global_position).normalized()
	_spawn_bullet(dir)
	AudioManager.play_sfx("shoot")


func _shoot_spread(count: int, spread_deg: float) -> void:
	var base_dir := (get_global_mouse_position() - global_position).normalized()
	var base_angle := base_dir.angle()
	var half := deg_to_rad(spread_deg) / 2.0
	for i in count:
		var t := float(i) / float(count - 1) if count > 1 else 0.0
		var angle := base_angle - half + t * half * 2.0
		_spawn_bullet(Vector2(cos(angle), sin(angle)))
	AudioManager.play_sfx("shoot")


func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir.normalized()
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	# Bullet ne sme da pogodi bossa — dodati u bullet.gd collision ignore ako treba
	get_tree().current_scene.add_child(bullet)

func _update_animation_state(_delta: float) -> void:
	if not sprite:
		return
	var moving := velocity.length_squared() > 1.0
	var anim := &"idle"
	if shoot_anim_timer > 0.0 and sprite.sprite_frames.has_animation("shoot"):
		anim = &"shoot"
	elif moving and sprite.sprite_frames.has_animation("run"):
		anim = &"run"
	_play_animation_set(anim, moving)

func _play_animation_set(anim: StringName, moving: bool) -> void:
	if sprite and sprite.sprite_frames.has_animation(anim):
		if sprite.animation != anim or not sprite.is_playing():
			sprite.play(anim)
	if outline_sprite and outline_sprite.sprite_frames and outline_sprite.sprite_frames.has_animation(anim):
		if outline_sprite.animation != anim or not outline_sprite.is_playing():
			outline_sprite.play(anim)
	var legs_anim: StringName = &"default"
	if legs_sprite and legs_sprite.sprite_frames and legs_sprite.sprite_frames.has_animation(legs_anim):
		if moving:
			if not legs_sprite.is_playing():
				legs_sprite.play(legs_anim)
		else:
			legs_sprite.stop()
			legs_sprite.frame = 0
	if outline_legs_sprite and outline_legs_sprite.sprite_frames and outline_legs_sprite.sprite_frames.has_animation(legs_anim):
		if moving:
			if not outline_legs_sprite.is_playing():
				outline_legs_sprite.play(legs_anim)
		else:
			outline_legs_sprite.stop()
			outline_legs_sprite.frame = 0

# ── Abilities ─────────────────────────────────────────────────────────────────

func _handle_abilities() -> void:
	if Input.is_action_just_pressed("boss_shrink"):
		activate_shrink()
	if Input.is_action_just_pressed("boss_summon"):
		summon_wave()


func activate_shrink() -> void:
	if shrink_cooldown_timer > 0.0:
		return
	shrink_cooldown_timer = shrink_cooldown_max
	shrink_activated.emit()
	AudioManager.play_sfx("boss_shrink")  # dodati SFX u AudioManager


func summon_wave() -> void:
	if summon_cooldown_timer > 0.0:
		return
	summon_cooldown_timer = summon_cooldown_max
	wave_summoned.emit()
	AudioManager.play_sfx("boss_summon")  # dodati SFX u AudioManager

# ── EMP Debuff ────────────────────────────────────────────────────────────────

## Poziva other_side_manager kad AI emituje emp_hit_boss.
func apply_emp_debuff() -> void:
	debuff_active = true
	debuff_timer = EMP_DEBUFF_DURATION
	# Vizualni feedback: plavi flash na svim slojevima.
	_set_visual_modulate(Color(0.4, 0.6, 1.0, 1.0), Color(0.05, 0.2, 0.45, 0.85))
	var tw := create_tween()
	_tween_visual_modulate(tw, Color.WHITE, OUTLINE_BASE_COLOR, 0.3)

# ── Damage / Smrt ─────────────────────────────────────────────────────────────

func take_damage(amount: int) -> void:
	if invincible:
		return
	current_hp -= amount
	current_hp = maxi(current_hp, 0)
	boss_damaged.emit(current_hp, max_hp)
	_check_phase()

	if current_hp <= 0:
		die()
		return

	invincible = true
	invincible_timer = invincible_duration
	# Crveni flash na svim slojevima.
	_set_visual_modulate(Color(1.5, 0.3, 0.3, 1.0), Color(0.25, 0.03, 0.03, 0.9))
	var tw := create_tween()
	_tween_visual_modulate(tw, Color.WHITE, OUTLINE_BASE_COLOR, 0.15)
	AudioManager.play_sfx("enemy_hit")


func die() -> void:
	set_physics_process(false)
	velocity = Vector2.ZERO
	if sprite and sprite.sprite_frames and sprite.sprite_frames.has_animation("death"):
		sprite.play("death")
		await sprite.animation_finished
	var mgr = get_tree().get_first_node_in_group("other_side_manager")
	if mgr:
		mgr._on_boss_died()


func _handle_invincibility(delta: float) -> void:
	if not invincible:
		return
	invincible_timer -= delta
	# Treperi dok je invincible
	_set_visual_visible(fmod(invincible_timer, 0.2) > 0.1)
	if invincible_timer <= 0.0:
		invincible = false
		_set_visual_visible(true)

# ── Faze ─────────────────────────────────────────────────────────────────────

func _check_phase() -> void:
	var pct := float(current_hp) / float(max_hp)
	var new_phase := 1
	if pct <= phase3_threshold:
		new_phase = 3
	elif pct <= phase2_threshold:
		new_phase = 2

	if new_phase != current_phase:
		current_phase = new_phase
		_enter_phase(current_phase)


func _enter_phase(phase: int) -> void:
	match phase:
		1:
			fire_rate = p1_fire_rate
			shrink_cooldown_max = p1_shrink_cooldown
		2:
			fire_rate = p2_fire_rate
			shrink_cooldown_max = p2_shrink_cooldown
		3:
			fire_rate = p3_fire_rate
			shrink_cooldown_max = p3_shrink_cooldown
	phase_changed.emit(phase)

# ── Utility ───────────────────────────────────────────────────────────────────

func get_shrink_cooldown_percent() -> float:
	if shrink_cooldown_max <= 0.0:
		return 1.0
	return 1.0 - (shrink_cooldown_timer / shrink_cooldown_max)


func get_summon_cooldown_percent() -> float:
	if summon_cooldown_max <= 0.0:
		return 1.0
	return 1.0 - (summon_cooldown_timer / summon_cooldown_max)

func _set_visual_visible(v: bool) -> void:
	if sprite:
		sprite.visible = v
	if outline_sprite:
		outline_sprite.visible = v
	if legs_sprite:
		legs_sprite.visible = v
	if outline_legs_sprite:
		outline_legs_sprite.visible = v

func _set_visual_modulate(main_color: Color, outline_color: Color) -> void:
	if sprite:
		sprite.modulate = main_color
	if legs_sprite:
		legs_sprite.modulate = main_color
	if outline_sprite:
		outline_sprite.modulate = outline_color
	if outline_legs_sprite:
		outline_legs_sprite.modulate = outline_color

func _tween_visual_modulate(tw: Tween, main_color: Color, outline_color: Color, dur: float) -> void:
	if sprite:
		tw.parallel().tween_property(sprite, "modulate", main_color, dur)
	if legs_sprite:
		tw.parallel().tween_property(legs_sprite, "modulate", main_color, dur)
	if outline_sprite:
		tw.parallel().tween_property(outline_sprite, "modulate", outline_color, dur)
	if outline_legs_sprite:
		tw.parallel().tween_property(outline_legs_sprite, "modulate", outline_color, dur)
