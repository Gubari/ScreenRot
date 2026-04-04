extends CanvasLayer

## HUD za "The Other Side" borbu.
##
## Layout:
##   Levo gore   — Boss HP bar (crvena)
##   Desno gore  — Light HP + screen% | Heavy HP + screen%
##   Dole levo   — Space cooldown (Shrink) | Shift cooldown (Summon)
##   Centar gore — Phase label
##   Centar      — EMP warning flash

# ── Node reference (podesiti u other_side_hud.tscn) ──────────────────────────

@onready var boss_hp_bar: ProgressBar       = $BossSection/BossHPBar
@onready var boss_hp_label: Label           = $BossSection/BossHPLabel

@onready var light_hp_bar: ProgressBar      = $AISection/LightGroup/LightHPBar
@onready var light_hp_label: Label          = $AISection/LightGroup/LightHPLabel
@onready var light_screen_bar: ProgressBar  = $AISection/LightGroup/LightScreenBar
@onready var light_screen_label: Label      = $AISection/LightGroup/LightScreenLabel

@onready var heavy_hp_bar: ProgressBar      = $AISection/HeavyGroup/HeavyHPBar
@onready var heavy_hp_label: Label          = $AISection/HeavyGroup/HeavyHPLabel
@onready var heavy_screen_bar: ProgressBar  = $AISection/HeavyGroup/HeavyScreenBar
@onready var heavy_screen_label: Label      = $AISection/HeavyGroup/HeavyScreenLabel

@onready var shrink_bar: ProgressBar        = $AbilitySection/ShrinkBar
@onready var shrink_label: Label            = $AbilitySection/ShrinkLabel
@onready var summon_bar: ProgressBar        = $AbilitySection/SummonBar
@onready var summon_label: Label            = $AbilitySection/SummonLabel

@onready var phase_label: Label             = $PhaseLabel
@onready var emp_warning: Label             = $EMPWarning

# ── Lifecycle ─────────────────────────────────────────────────────────────────

func _ready() -> void:
	emp_warning.visible = false
	phase_label.text = "PHASE 1"
	shrink_label.text = "SHRINK [SPACE]"
	summon_label.text = "SUMMON [SHIFT]"


func _process(_delta: float) -> void:
	# Cooldown barovi se update-uju svaki frame iz player_boss referenci
	# TODO: dobiti referencu na player_boss i citati get_shrink_cooldown_percent()
	pass

# ── Boss HP ───────────────────────────────────────────────────────────────────

func update_boss_hp(current: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	var pct := float(current) / float(max_hp) * 100.0
	boss_hp_bar.value = pct
	boss_hp_label.text = str(current) + " / " + str(max_hp)
	# Boja: zelena → narandzasta → crvena
	if pct > 60.0:
		boss_hp_bar.modulate = Color.GREEN
	elif pct > 30.0:
		boss_hp_bar.modulate = Color.ORANGE
	else:
		boss_hp_bar.modulate = Color.RED

# ── AI HP i screen % ─────────────────────────────────────────────────────────

func update_ai_hp(ai_type: String, current: int, max_hp: int) -> void:
	if max_hp <= 0:
		return
	var pct := float(current) / float(max_hp) * 100.0
	if ai_type == "light":
		light_hp_bar.value = pct
		light_hp_label.text = "LIGHT  " + str(current) + "/" + str(max_hp)
	else:
		heavy_hp_bar.value = pct
		heavy_hp_label.text = "HEAVY  " + str(current) + "/" + str(max_hp)


func update_screen_percent(ai_type: String, percent: float) -> void:
	if ai_type == "light":
		light_screen_bar.value = percent
		light_screen_label.text = "SCR " + str(int(percent)) + "%"
		light_screen_bar.modulate = _screen_color(percent)
	else:
		heavy_screen_bar.value = percent
		heavy_screen_label.text = "SCR " + str(int(percent)) + "%"
		heavy_screen_bar.modulate = _screen_color(percent)


func _screen_color(percent: float) -> Color:
	if percent > 80.0:
		return Color.GREEN
	elif percent > 50.0:
		return Color.YELLOW
	else:
		return Color.RED

# ── Ability cooldowni ─────────────────────────────────────────────────────────

func update_shrink_cooldown(percent: float) -> void:
	shrink_bar.value = percent * 100.0
	shrink_bar.modulate = Color.CYAN if percent >= 1.0 else Color(0.4, 0.8, 0.9, 1.0)


func update_summon_cooldown(percent: float) -> void:
	summon_bar.value = percent * 100.0
	summon_bar.modulate = Color.ORANGE if percent >= 1.0 else Color(0.8, 0.5, 0.2, 1.0)

# ── Phase label ───────────────────────────────────────────────────────────────

func show_phase(phase: int) -> void:
	phase_label.text = "PHASE " + str(phase)
	var col := Color.GREEN
	match phase:
		2: col = Color.ORANGE
		3: col = Color.RED
	phase_label.modulate = col
	# Kratka animacija
	phase_label.scale = Vector2(1.4, 1.4)
	var tw := create_tween()
	tw.tween_property(phase_label, "scale", Vector2.ONE, 0.3).set_trans(Tween.TRANS_BACK)

# ── EMP Warning ───────────────────────────────────────────────────────────────

func flash_emp_warning() -> void:
	emp_warning.text = "!  EMP  !"
	emp_warning.visible = true
	emp_warning.modulate = Color.CYAN
	var tw := create_tween()
	tw.tween_property(emp_warning, "modulate:a", 0.0, 1.2).set_delay(0.3)
	tw.tween_callback(func(): emp_warning.visible = false)
