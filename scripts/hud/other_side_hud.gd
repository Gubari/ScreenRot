extends CanvasLayer

## HUD za "The Other Side" borbu.
##
## Layout (isti vizualni stil kao gameplay_hud):
##   Levo gore   — Boss HP bar (TextureRect, hp_frame atlas)
##   Levo        — Summon cooldown bar (TextureRect, dash_frame atlas)
##   Levo        — Shrink cooldown bar (TextureRect, dash_frame atlas)
##   Centar gore — Light boss bar (ProgressBar)
##   Centar gore — Heavy boss bar (ProgressBar)
##   Centar      — Wave label

# ── Node reference ───────────────────────────────────────────────────────────

@onready var hp_bar: TextureRect = $HPBar
@onready var hp_label: Label = $HPLabel

@onready var summon_bar: TextureRect = $SummonBar
@onready var summon_label: Label = $SummonLabel

@onready var shrink_bar: TextureRect = $ShrinkBar
@onready var shrink_label: Label = $ShrinkLabel

@onready var light_bar_container: VBoxContainer = $LightBarContainer
@onready var light_name_label: Label = $LightBarContainer/LightNameLabel
@onready var light_health_bar: ProgressBar = $LightBarContainer/LightHealthBar

@onready var heavy_bar_container: VBoxContainer = $HeavyBarContainer
@onready var heavy_name_label: Label = $HeavyBarContainer/HeavyNameLabel
@onready var heavy_health_bar: ProgressBar = $HeavyBarContainer/HeavyHealthBar

@onready var score_label: Label = $ScorePanel/ScoreLabel
@onready var credits_label: Label = $CreditsPanel/CreditsLabel

@onready var wave_label: Label = $WaveLabel

# ── Atlas frames ─────────────────────────────────────────────────────────────

var _hp_frames: Array[AtlasTexture] = []
var _dash_frames: Array[AtlasTexture] = []

# ── Lifecycle ────────────────────────────────────────────────────────────────

func _ready() -> void:
	add_to_group("other_side_hud")
	for i in 10:
		_hp_frames.append(load("res://resources/hud/hp_frame_%d.tres" % i))
	for i in 27:
		_dash_frames.append(load("res://resources/hud/dash_frame_%d.tres" % i))

	summon_label.text = "SUMMON"
	shrink_label.text = "SHRINK"
	light_name_label.text = "LIGHT"
	heavy_name_label.text = "HEAVY"

# ── Boss HP (levo gore, isti kao player HP u gameplay_hud) ───────────────────

func update_boss_hp(current: int, max_hp: int) -> void:
	hp_label.text = str(current) + " / " + str(max_hp)
	var frame: int
	if max_hp <= 0 or current <= 0:
		frame = 0
	else:
		var pct := float(current) / float(max_hp)
		frame = clampi(int(pct * _hp_frames.size()), 1, _hp_frames.size() - 1)
	hp_bar.texture = _hp_frames[frame]

# ── AI boss barovi (centar gore) ─────────────────────────────────────────────

func update_ai_hp(ai_type: String, current: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	var pct := float(current) / float(max_hp) * 100.0
	if ai_type == "light":
		light_health_bar.value = pct
		_color_boss_bar(light_health_bar, pct)
	else:
		heavy_health_bar.value = pct
		_color_boss_bar(heavy_health_bar, pct)


func _color_boss_bar(bar: ProgressBar, pct: float) -> void:
	if pct > 60.0:
		bar.modulate = Color.GREEN
	elif pct > 30.0:
		bar.modulate = Color.ORANGE
	else:
		bar.modulate = Color.RED


func hide_ai_bar(ai_type: String) -> void:
	if ai_type == "light":
		light_bar_container.visible = false
	else:
		heavy_bar_container.visible = false

# ── Summon cooldown (isti vizual kao Dash bar) ───────────────────────────────

func update_summon_cooldown(percent: float) -> void:
	var frame := clampi(roundi(percent * (_dash_frames.size() - 1)), 0, _dash_frames.size() - 1)
	summon_bar.texture = _dash_frames[frame]

# ── Shrink cooldown (isti vizual kao Dash bar, cyan tint) ────────────────────

func update_shrink_cooldown(percent: float) -> void:
	var frame := clampi(roundi(percent * (_dash_frames.size() - 1)), 0, _dash_frames.size() - 1)
	shrink_bar.texture = _dash_frames[frame]

# ── Score / Credits ──────────────────────────────────────────────────────────

func update_score(score: int) -> void:
	score_label.text = "Score: " + str(score)


func update_credits(amount: int) -> void:
	credits_label.text = "Credits: " + str(amount)

# ── Wave label ───────────────────────────────────────────────────────────────

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
