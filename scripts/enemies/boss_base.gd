extends EnemyBase
class_name BossBase

signal boss_defeated(boss_id: String, score: int)
signal phase_changed(phase: int)
signal request_screen_shrink(rate: float)
@warning_ignore("unused_signal")
signal request_screen_restore(amount: float)
signal request_zoom(target_zoom: float)
signal fragment_spawn_requested(world_pos: Vector2, value: float)
signal boss_wave_requested(queue: Array)

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
@export var p2_spread_angle: float = 45.0
@export var p2_fragment_rate: float = 3.0
@export var p2_fragment_value: float = 10.0
@export var p2_immune_threshold: float = 50.0
@export var p2_zoom_per_shot: float = 0.02
@export var p2_max_zoom: float = 1.4

# Phase 3 config
@export var p3_shrink_rate: float = 6.0
@export var p3_fire_rate: float = 0.6
@export var p3_move_speed: float = 100.0
@export var p3_spread_count: int = 5
@export var p3_spread_angle: float = 60.0
@export var p3_fragment_rate: float = 2.5
@export var p3_fragment_value: float = 8.0
@export var p3_immune_threshold: float = 60.0
@export var p3_panic_threshold: float = 20.0

# Boss wave spawns per phase (uses same SpawnGroup resource as regular waves)
@export_group("Boss Waves")
@export var p1_wave: Array[SpawnGroup] = []
@export var p2_wave: Array[SpawnGroup] = []
@export var p3_wave: Array[SpawnGroup] = []
@export_group("")

var current_phase: int = 0
var fire_timer: float = 0.0
var fragment_timer: float = 0.0
var is_dying: bool = false
var is_transitioning: bool = false
## Countdown before boss starts shooting (set on spawn to match cinematic return duration).
var intro_timer: float = 2.5
var current_zoom: float = 1.0
var screen_percent: float = 100.0
var screen_closing: CanvasLayer = null
var dungeon_map: Node2D = null

var bullet_scene: PackedScene = preload("res://scenes/enemies/boss_bullet.tscn")
var fragment_scene: PackedScene = preload("res://scenes/effects/screen_fragment.tscn")

const LEG_CUTOUT_SHADER: Shader = preload("res://shaders/boss_leg_cutout_only.gdshader")

func _ready() -> void:
	enemy_type = "boss"
	super._ready()
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	var ol := get_node_or_null("Outline") as AnimatedSprite2D
	if spr and LEG_CUTOUT_SHADER:
		var mat := ShaderMaterial.new()
		mat.shader = LEG_CUTOUT_SHADER
		mat.set_shader_parameter("leg_cutout_uv_y", -1.0)
		spr.material = mat
	var outline_tex := load("res://assets/sprites/enemies/BloatwareBoss/boss_outline_x3.png") as Texture2D
	if ol and spr and spr.sprite_frames and outline_tex and LEG_CUTOUT_SHADER:
		ol.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		ol.sprite_frames = _sprite_frames_with_outline_atlas(spr.sprite_frames, outline_tex)
		ol.animation = spr.animation
		ol.frame = spr.frame
		var omat := ShaderMaterial.new()
		omat.shader = LEG_CUTOUT_SHADER
		omat.set_shader_parameter("leg_cutout_uv_y", -1.0)
		ol.material = omat
	if has_node("Legs"):
		var legs := get_node_or_null("Legs") as AnimatedSprite2D
		if legs:
			legs.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
			legs.material = null
	_enter_phase(1)

func _physics_process(delta: float) -> void:
	if is_transitioning:
		return
	if is_dying:
		_sync_boss_death_visuals()
		return
	super._physics_process(delta)
	if intro_timer > 0.0:
		intro_timer -= delta
	if player and is_instance_valid(player) and player.visible:
		if intro_timer <= 0.0:
			_handle_shooting(delta)
		_handle_fragment_spawning(delta)
		_update_animation()
	_sync_boss_outline_with_sprite()
	_sync_boss_legs_layer()

func do_movement(delta: float) -> void:
	if not player or not is_instance_valid(player):
		return
	super.do_movement(delta)
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	if spr:
		spr.flip_h = velocity.x < 0.0
	var legs := get_node_or_null("Legs") as AnimatedSprite2D
	var ol_legs := get_node_or_null("OutlineLegs") as AnimatedSprite2D
	if legs:
		legs.flip_h = spr.flip_h if spr else false
	if ol_legs:
		ol_legs.flip_h = spr.flip_h if spr else false

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
	var groups: Array[SpawnGroup] = []
	match phase:
		1: groups = p1_wave
		2: groups = p2_wave
		3: groups = p3_wave
	if groups.size() > 0:
		var queue: Array = []
		for g in groups:
			queue.append({
				"type": g.enemy_type,
				"count": g.count,
				"delay": g.delay_before_spawn,
			})
		boss_wave_requested.emit(queue)
	_sync_nav_agent_max_speed()

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
		if is_dying:
			return
		if spr.sprite_frames.has_animation("run"):
			spr.play("run")

	if is_dying or not player or not is_instance_valid(player):
		return

	match current_phase:
		1:
			_shoot_single()
		2:
			_shoot_spread(p2_spread_count, p2_spread_angle)
		3:
			_shoot_spread(p3_spread_count, p3_spread_angle)

func _shoot_single() -> void:
	var dir = (player.global_position - global_position).normalized()
	_spawn_bullet(dir)

func _shoot_spread(count: int, spread_deg: float) -> void:
	var base_dir = (player.global_position - global_position).normalized()
	var base_angle = base_dir.angle()
	var half_spread = deg_to_rad(spread_deg) / 2.0
	for i in count:
		var t := 0.0
		if count > 1:
			t = float(i) / float(count - 1)  # 0 to 1
		var angle = base_angle - half_spread + t * half_spread * 2.0
		_spawn_bullet(Vector2(cos(angle), sin(angle)))
	# Zoom effect
	current_zoom = minf(current_zoom + p2_zoom_per_shot, p2_max_zoom)
	request_zoom.emit(current_zoom)

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

# ── Outline atlas (isti grid kao boss_x3) + noge pri shoot ─────────────────

func _sprite_frames_with_outline_atlas(sf: SpriteFrames, outline_tex: Texture2D) -> SpriteFrames:
	var out := sf.duplicate(true) as SpriteFrames
	for anim_name in out.get_animation_names():
		for i in range(out.get_frame_count(anim_name)):
			var t := out.get_frame_texture(anim_name, i)
			if t is AtlasTexture:
				var at := (t as AtlasTexture).duplicate() as AtlasTexture
				at.atlas = outline_tex
				var dur := out.get_frame_duration(anim_name, i)
				out.set_frame(anim_name, i, at, dur)
	return out


func _sync_boss_death_visuals() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	var ol := get_node_or_null("Outline") as AnimatedSprite2D
	if not spr or not ol:
		return
	if ol.animation != spr.animation:
		ol.animation = spr.animation
	ol.frame = spr.frame
	ol.flip_h = spr.flip_h


func _sync_boss_outline_with_sprite() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	var ol := get_node_or_null("Outline") as AnimatedSprite2D
	if not spr or not ol or not ol.sprite_frames:
		return
	if ol.animation != spr.animation:
		ol.animation = spr.animation
	ol.frame = spr.frame
	ol.flip_h = spr.flip_h


func _sync_boss_legs_layer() -> void:
	var spr := get_node_or_null("Sprite") as AnimatedSprite2D
	var legs := get_node_or_null("Legs") as AnimatedSprite2D
	var ol := get_node_or_null("Outline") as AnimatedSprite2D
	if not spr:
		return
	var cut_v := -1.0
	if legs and spr.animation == "shoot" and not is_dying:
		cut_v = 0.69
	if spr.material is ShaderMaterial:
		spr.material.set_shader_parameter("leg_cutout_uv_y", cut_v)
	if ol and ol.material is ShaderMaterial:
		ol.material.set_shader_parameter("leg_cutout_uv_y", cut_v)
	if not legs:
		var oll := get_node_or_null("OutlineLegs") as AnimatedSprite2D
		if oll:
			oll.visible = false
		return
	var ol_legs := get_node_or_null("OutlineLegs") as AnimatedSprite2D
	if spr.animation == "shoot" and not is_dying:
		legs.visible = true
		var anim_name := "default"
		if legs.sprite_frames and legs.sprite_frames.has_animation(anim_name):
			var fc := legs.sprite_frames.get_frame_count(anim_name)
			if fc > 0:
				legs.frame = spr.frame % fc
		if ol_legs:
			ol_legs.visible = true
			if ol_legs.sprite_frames and ol_legs.sprite_frames.has_animation(anim_name):
				var ofc := ol_legs.sprite_frames.get_frame_count(anim_name)
				if ofc > 0:
					ol_legs.frame = spr.frame % ofc
			ol_legs.flip_h = spr.flip_h
	else:
		legs.visible = false
		if ol_legs:
			ol_legs.visible = false


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
	var ol := get_node_or_null("Outline") as AnimatedSprite2D
	var legs := get_node_or_null("Legs") as AnimatedSprite2D
	var ol_legs := get_node_or_null("OutlineLegs") as AnimatedSprite2D
	if legs:
		legs.visible = false
	if ol_legs:
		ol_legs.visible = false
	if spr and spr.sprite_frames.has_animation("death"):
		spr.play("death")
		if ol and ol.sprite_frames and ol.sprite_frames.has_animation("death"):
			ol.play("death")
		await spr.animation_finished
	AudioManager.play_sfx("enemy_kill")
	enemy_killed.emit(global_position, enemy_type)
	boss_defeated.emit(boss_id, score_value)
	if player and player.has_method("add_score"):
		player.add_score(score_value)
	queue_free()
