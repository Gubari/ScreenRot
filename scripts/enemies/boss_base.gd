extends EnemyBase
class_name BossBase

signal boss_defeated(boss_id: String, score: int)
signal phase_changed(phase: int)
signal request_screen_shrink(rate: float)
signal request_screen_restore(amount: float)
signal request_zoom(target_zoom: float)
signal fragment_spawn_requested(world_pos: Vector2, value: float)

@export var boss_id: String = "bloatware"
@export var bullet_damage: int = 1
@export var fire_rate: float = 1.0
@export var bullet_speed: float = 600.0

# Phase thresholds (percent of max_hp)
@export var phase2_threshold: float = 0.6
@export var phase3_threshold: float = 0.3

# Phase 1 config
@export var p1_shrink_rate: float = 2.0
@export var p1_fire_rate: float = 1.0
@export var p1_move_speed: float = 40.0
@export var p1_fragment_rate: float = 3.0
@export var p1_fragment_value: float = 15.0
@export var p1_immune_threshold: float = 50.0

# Phase 2 config
@export var p2_shrink_rate: float = 4.0
@export var p2_fire_rate: float = 0.8
@export var p2_move_speed: float = 70.0
@export var p2_spread_count: int = 3
@export var p2_spread_angle: float = 25.0
@export var p2_fragment_rate: float = 3.0
@export var p2_fragment_value: float = 10.0
@export var p2_immune_threshold: float = 50.0
@export var p2_zoom_per_shot: float = 0.02
@export var p2_max_zoom: float = 1.4

# Phase 3 config
@export var p3_shrink_rate: float = 6.0
@export var p3_fire_rate: float = 0.6
@export var p3_move_speed: float = 100.0
@export var p3_ring_count: int = 8
@export var p3_fragment_rate: float = 2.5
@export var p3_fragment_value: float = 8.0
@export var p3_immune_threshold: float = 60.0
@export var p3_panic_threshold: float = 20.0

var current_phase: int = 0
var fire_timer: float = 0.0
var fragment_timer: float = 0.0
var is_dying: bool = false
var is_transitioning: bool = false
var current_zoom: float = 1.0
var screen_percent: float = 100.0
var screen_closing: CanvasLayer = null
var dungeon_map: Node2D = null

var bullet_scene: PackedScene = preload("res://scenes/enemies/boss_bullet.tscn")
var fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

func _ready() -> void:
	enemy_type = "boss"
	super._ready()
	_enter_phase(1)

func _physics_process(delta: float) -> void:
	if is_dying or is_transitioning:
		return
	super._physics_process(delta)
	if player and is_instance_valid(player) and player.visible:
		_handle_shooting(delta)
		_handle_fragment_spawning(delta)
		_update_animation()

func do_movement(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	super.do_movement(delta)
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = velocity.x < 0.0

# ── Phase management ──────────────────────────────────────────

func _enter_phase(phase: int) -> void:
	current_phase = phase
	match phase:
		1:
			fire_rate = p1_fire_rate
			move_speed = p1_move_speed
			fragment_timer = p1_fragment_rate
			request_screen_shrink.emit(p1_shrink_rate)
		2:
			fire_rate = p2_fire_rate
			move_speed = p2_move_speed
			fragment_timer = p2_fragment_rate
			request_screen_shrink.emit(p2_shrink_rate)
		3:
			fire_rate = p3_fire_rate
			move_speed = p3_move_speed
			fragment_timer = p3_fragment_rate
			request_screen_shrink.emit(p3_shrink_rate)
	fire_timer = fire_rate
	phase_changed.emit(phase)

func take_damage(amount: int) -> void:
	if is_dying or is_transitioning:
		return

	# Check immunity: boss is immune when hidden behind black bars
	if _is_hidden_by_bars():
		flash_immune()
		return

	current_hp -= amount
	flash_white()
	AudioManager.play_sfx("enemy_hit")

	if current_hp <= 0:
		die()
		return

	# Check phase transitions
	var hp_percent := float(current_hp) / float(max_hp)
	if current_phase == 1 and hp_percent <= phase2_threshold:
		_transition_to_phase(2)
	elif current_phase == 2 and hp_percent <= phase3_threshold:
		_transition_to_phase(3)

func _is_hidden_by_bars() -> bool:
	if not screen_closing or not screen_closing.has_method("get_visible_area"):
		return false
	var visible_rect: Rect2 = screen_closing.get_visible_area()
	# Convert boss world position to viewport (screen) coordinates
	var cam := get_viewport().get_camera_2d()
	if not cam:
		return false
	var vp_size := get_viewport().get_visible_rect().size
	var screen_pos := vp_size * 0.5 + (global_position - cam.global_position) * cam.zoom
	return not visible_rect.has_point(screen_pos)

func flash_immune() -> void:
	modulate = Color(0.3, 0.3, 1.0, 1.0)
	var tween = create_tween()
	tween.tween_property(self, "modulate", Color.WHITE, 0.15)

func _transition_to_phase(phase: int) -> void:
	is_transitioning = true
	velocity = Vector2.ZERO

	# Flash effect
	var flash_color := Color.ORANGE if phase == 2 else Color.RED
	modulate = flash_color
	var tw := create_tween()
	tw.tween_property(self, "modulate", Color.WHITE, 0.3)
	await tw.finished

	if not is_instance_valid(self):
		return

	var pause_time := 1.0 if phase == 2 else 1.5

	# Phase 3 mercy reset: give player some screen back
	if phase == 3:
		request_screen_restore.emit(40.0)

	await get_tree().create_timer(pause_time).timeout

	if not is_instance_valid(self):
		return

	is_transitioning = false
	_enter_phase(phase)

func set_screen_percent(value: float) -> void:
	screen_percent = value

# ── Shooting ──────────────────────────────────────────────────

func _handle_shooting(delta: float) -> void:
	fire_timer -= delta
	# Phase 3 panic: double fire rate when screen is very low
	if current_phase == 3 and screen_percent < p3_panic_threshold:
		fire_timer -= delta  # ticks twice as fast
	if fire_timer <= 0:
		fire_timer = fire_rate
		_shoot()

func _shoot() -> void:
	if not player or not is_instance_valid(player):
		return
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and spr.sprite_frames.has_animation("shoot"):
		spr.play("shoot")
		await spr.animation_finished
		if not is_instance_valid(self):
			return
		if spr.sprite_frames.has_animation("run"):
			spr.play("run")

	if not player or not is_instance_valid(player):
		return

	match current_phase:
		1:
			_shoot_single()
		2:
			_shoot_spread()
		3:
			_shoot_ring()

func _shoot_single() -> void:
	var dir = (player.global_position - global_position).normalized()
	_spawn_bullet(dir)

func _shoot_spread() -> void:
	var base_dir = (player.global_position - global_position).normalized()
	var base_angle = base_dir.angle()
	var half_spread = deg_to_rad(p2_spread_angle) / 2.0
	for i in p2_spread_count:
		var t := 0.0
		if p2_spread_count > 1:
			t = float(i) / float(p2_spread_count - 1)  # 0 to 1
		var angle = base_angle - half_spread + t * half_spread * 2.0
		_spawn_bullet(Vector2(cos(angle), sin(angle)))
	# Zoom effect
	current_zoom = minf(current_zoom + p2_zoom_per_shot, p2_max_zoom)
	request_zoom.emit(current_zoom)

func _shoot_ring() -> void:
	var angle_step = TAU / float(p3_ring_count)
	for i in p3_ring_count:
		var angle = i * angle_step
		_spawn_bullet(Vector2(cos(angle), sin(angle)))

func _spawn_bullet(dir: Vector2) -> void:
	var bullet = bullet_scene.instantiate()
	bullet.global_position = global_position
	bullet.direction = dir.normalized()
	bullet.speed = bullet_speed
	bullet.damage = bullet_damage
	get_tree().current_scene.add_child(bullet)

# ── Fragment spawning ─────────────────────────────────────────

func _handle_fragment_spawning(delta: float) -> void:
	fragment_timer -= delta
	if fragment_timer <= 0:
		match current_phase:
			1:
				fragment_timer = p1_fragment_rate
				_spawn_fragment(p1_fragment_value)
			2:
				fragment_timer = p2_fragment_rate
				_spawn_fragment(p2_fragment_value)
			3:
				fragment_timer = p3_fragment_rate
				_spawn_fragment(p3_fragment_value)

func _spawn_fragment(value: float) -> void:
	if not player or not is_instance_valid(player):
		return
	# Try up to 10 times to find a walkable position around the player
	for i in 10:
		var angle = randf() * TAU
		var dist = randf_range(100.0, 300.0)
		var pos = player.global_position + Vector2(cos(angle), sin(angle)) * dist
		if dungeon_map and dungeon_map.has_method("is_walkable") and not dungeon_map.is_walkable(pos):
			continue
		fragment_spawn_requested.emit(pos, value)
		return

# ── Animation ─────────────────────────────────────────────────

func _update_animation() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if not spr:
		return
	if spr.animation == "shoot":
		return
	if velocity.length() > 5.0:
		if spr.sprite_frames.has_animation("run"):
			if spr.animation != "run":
				spr.play("run")
	else:
		if spr.sprite_frames.has_animation("idle"):
			if spr.animation != "idle":
				spr.play("idle")

# ── Death ─────────────────────────────────────────────────────

func die() -> void:
	if is_dying:
		return
	is_dying = true
	velocity = Vector2.ZERO
	# Reset all screen effects
	request_screen_shrink.emit(0.0)
	request_zoom.emit(1.0)
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr and spr.sprite_frames.has_animation("death"):
		spr.play("death")
		await spr.animation_finished
	AudioManager.play_sfx("enemy_kill")
	enemy_killed.emit(global_position, enemy_type)
	boss_defeated.emit(boss_id, score_value)
	if player and player.has_method("add_score"):
		player.add_score(score_value)
	queue_free()
