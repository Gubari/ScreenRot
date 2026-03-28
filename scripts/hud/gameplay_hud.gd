extends CanvasLayer

@onready var hp_label: Label = $HPLabel
@onready var hp_bar: TextureRect = $HPBar
@onready var dash_label: Label = $DashLabel
@onready var dash_bar: TextureRect = $DashBar
@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var multiplier_label: Label = $MultiplierLabel
@onready var credits_label: Label = $CreditsPanel/CreditsLabel
@onready var debris_bar: ProgressBar = $DebrisBar
@onready var debris_label: Label = $DebrisLabel
@onready var wave_label: Label = $WaveLabel
@onready var boss_bar_container: VBoxContainer = $BossBarContainer
@onready var boss_name_label: Label = $BossBarContainer/BossNameLabel
@onready var boss_health_bar: ProgressBar = $BossBarContainer/BossHealthBar

# HP frames: 10 AtlasTexture resources loaded from res://resources/hud/hp_frame_0..9.tres
# Edit each .tres in the Godot editor to pick the exact sprite region you want.
# Frame 0 = lowest HP, frame 9 = full HP.
var _hp_frames: Array[AtlasTexture] = []

# Dash frames: 27 AtlasTexture resources from res://resources/hud/dash_frame_0..26.tres
# Frame 0 = empty (just dashed), frame 26 = full (dash ready).
var _dash_frames: Array[AtlasTexture] = []


func _ready() -> void:
	for i in 10:
		_hp_frames.append(load("res://resources/hud/hp_frame_%d.tres" % i))
	for i in 27:
		_dash_frames.append(load("res://resources/hud/dash_frame_%d.tres" % i))


func update_hp(current: int, max_hp: int) -> void:
	hp_label.text = str(current) + " / " + str(max_hp)
	# Frame based on HP percentage: 100% = frame 9, 0% = frame 0.
	# Each frame represents ~10% of max HP.
	var frame: int
	if max_hp <= 0 or current <= 0:
		frame = 0
	else:
		var pct := float(current) / float(max_hp)
		frame = clampi(int(pct * _hp_frames.size()), 1, _hp_frames.size() - 1)
	hp_bar.texture = _hp_frames[frame]


func update_score(score: int) -> void:
	score_label.text = "Score: " + str(score)


func update_multiplier(mult: int) -> void:
	multiplier_label.text = "x" + str(mult)


func update_dash(percent: float) -> void:
	var frame := clampi(roundi(percent * (_dash_frames.size() - 1)), 0, _dash_frames.size() - 1)
	dash_bar.texture = _dash_frames[frame]


func update_debris(percent: float, label_text: String, color: Color) -> void:
	debris_bar.value = percent
	debris_label.text = label_text
	debris_bar.modulate = color
	debris_label.modulate = color


func update_credits(amount: int) -> void:
	credits_label.text = "Credits: " + str(amount)


func show_wave(text: String) -> void:
	wave_label.text = text
	wave_label.visible = true
	wave_label.modulate.a = 1.0


func fade_wave_label() -> Tween:
	var tween := create_tween()
	tween.tween_property(wave_label, "modulate:a", 0.0, 1.5).set_delay(1.0)
	return tween


func hide_wave_label() -> void:
	wave_label.visible = false


func show_boss_bar(boss_name: String) -> void:
	boss_name_label.text = boss_name
	boss_health_bar.value = 100.0
	boss_bar_container.visible = true


func update_boss_hp(percent: float) -> void:
	boss_health_bar.value = percent


func update_boss_bar_color(color: Color) -> void:
	boss_health_bar.modulate = color


func hide_boss_bar() -> void:
	boss_bar_container.visible = false
