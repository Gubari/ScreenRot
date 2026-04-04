# THE OTHER SIDE — Dalji razvoj i testiranje

---

## Sta je vec gotovo (ne dirati)

| Fajl | Status |
|------|--------|
| `scripts/other_side/ai_screen_overlay.gd` | Kompletno |
| `scripts/other_side/player_boss.gd` | Skeleton — popuniti TODO |
| `scripts/other_side/ai_player.gd` | Skeleton — popuniti TODO |
| `scripts/other_side/other_side_manager.gd` | Skeleton — popuniti TODO |
| `scripts/hud/other_side_hud.gd` | Skeleton — popuniti TODO |
| `scripts/managers/game_manager.gd` | Modifikovan — portal trigger dodat |
| `project.godot` | `boss_shrink` (Space) i `boss_summon` (Shift) dodati |

---

## Sta treba uraditi po prioritetu

### PRIORITET 1 — Scena (mora prva, sve ostalo zavisi od nje)

Kreirati u Godot editoru: `scenes/other_side.tscn`

```
other_side (Node2D)  ← root, attach: other_side_manager.gd
├── DungeonMap (dungeon_map.tscn)
├── NavigationRegion2D          ← OBAVEZNO za AI pathfinding
│     └── (bake navigation mesh iz DungeonMap-a)
├── PlayerBoss (CharacterBody2D) ← attach: player_boss.gd
│     ├── Sprite (AnimatedSprite2D)   ← reuse boss sprite
│     ├── CollisionShape2D
│     └── Camera2D
├── AILight (CharacterBody2D)   ← attach: ai_player.gd
│     ├── Sprite (AnimatedSprite2D)   ← reuse player red_small sprite
│     ├── CollisionShape2D
│     ├── AIScreenOverlay (Node2D)    ← attach: ai_screen_overlay.gd
│     └── HitArea (Area2D)            ← za fragment detekciju
├── AIHeavy (CharacterBody2D)   ← attach: ai_player.gd
│     ├── Sprite (AnimatedSprite2D)   ← reuse player red_heavy sprite
│     ├── CollisionShape2D
│     ├── AIScreenOverlay (Node2D)    ← attach: ai_screen_overlay.gd
│     └── HitArea (Area2D)
├── EnemySpawner (enemy_spawner.tscn) ← reuse
├── HUD (CanvasLayer)
│     └── OtherSideHUD              ← attach: other_side_hud.gd
└── ScreenClosing (screen_closing.tscn) ← reuse (samo vizual)
```

**Export vrednosti u AILight inspektoru:**
```
ai_type = "light"
max_hp = 8
move_speed = 180.0
fire_rate = 0.4
has_dash = true
emp_cooldown = 12.0
has_shield = false
```

**Export vrednosti u AIHeavy inspektoru:**
```
ai_type = "heavy"
max_hp = 18
move_speed = 100.0
fire_rate = 0.7
has_dash = false
emp_cooldown = 18.0
has_shield = true
```

---

### PRIORITET 2 — player_boss.gd (popuniti TODO)

Fajl: `scripts/other_side/player_boss.gd`

**`_handle_movement()`** — kopirati iz `player.gd:handle_movement()`, prilagoditi:
```gdscript
func _handle_movement() -> void:
    var input_dir := Vector2(
        Input.get_axis("move_left", "move_right"),
        Input.get_axis("move_up", "move_down")
    ).normalized()
    var effective_speed := move_speed * (EMP_SPEED_MULT if debuff_active else 1.0)
    velocity = MovementFormula.velocity(input_dir, effective_speed)
```

**`_handle_rotation()`** — kopirati iz `player.gd:handle_rotation()`:
```gdscript
func _handle_rotation() -> void:
    var mouse_pos := get_global_mouse_position()
    sprite.flip_h = mouse_pos.x < global_position.x
```

**`_shoot_single()`**:
```gdscript
func _shoot_single() -> void:
    var dir := (get_global_mouse_position() - global_position).normalized()
    _spawn_bullet(dir)
    AudioManager.play_sfx("shoot")
```

**`_shoot_spread(count, spread_deg)`** — kopirati iz `boss_base.gd:_shoot_spread()`:
```gdscript
func _shoot_spread(count: int, spread_deg: float) -> void:
    var base_dir := (get_global_mouse_position() - global_position).normalized()
    var base_angle := base_dir.angle()
    var half := deg_to_rad(spread_deg) / 2.0
    for i in count:
        var t := float(i) / float(count - 1) if count > 1 else 0.0
        var angle := base_angle - half + t * half * 2.0
        _spawn_bullet(Vector2(cos(angle), sin(angle)))
    AudioManager.play_sfx("shoot")
```

**`die()`**:
```gdscript
func die() -> void:
    set_physics_process(false)
    velocity = Vector2.ZERO
    # Emitovati signal ka manageru — manager ce prikazati game over
    # Koristiti get_tree().get_first_node_in_group("other_side_manager")
    var mgr = get_tree().get_first_node_in_group("other_side_manager")
    if mgr:
        mgr._on_boss_died()
```

**HUD update u `_process`** — dodati na kraju `_physics_process`:
```gdscript
# Azurirati cooldown barove u HUD-u
var hud = get_tree().get_first_node_in_group("other_side_hud")
if hud:
    hud.update_shrink_cooldown(get_shrink_cooldown_percent())
    hud.update_summon_cooldown(get_summon_cooldown_percent())
```

---

### PRIORITET 3 — ai_player.gd (popuniti TODO)

Fajl: `scripts/other_side/ai_player.gd`

**`_do_chase()`** — kopirati logiku iz `enemy_base.gd:do_movement()`:
```gdscript
func _do_chase(_delta: float) -> void:
    if not boss or not is_instance_valid(boss):
        return
    nav_agent.target_position = boss.global_position
    var dir := (nav_agent.get_next_path_position() - global_position).normalized()
    var desired := MovementFormula.velocity(dir, move_speed)
    if nav_agent.avoidance_enabled:
        nav_agent.set_velocity(desired)
    else:
        velocity = desired
```

**`_do_collect()`** — isti pattern, target = fragment pozicija:
```gdscript
func _do_collect(_delta: float) -> void:
    var frag := _find_nearest_fragment()
    if not frag:
        current_state = State.CHASE
        return
    nav_agent.target_position = frag.global_position
    var dir := (nav_agent.get_next_path_position() - global_position).normalized()
    velocity = MovementFormula.velocity(dir, move_speed)
```

**`_shoot()`**:
```gdscript
func _shoot() -> void:
    if not boss or not is_instance_valid(boss):
        return
    var bullet = bullet_scene.instantiate()
    var dir := (boss.global_position - global_position).normalized()
    bullet.global_position = global_position
    bullet.direction = dir
    bullet.speed = bullet_speed
    bullet.damage = bullet_damage
    get_tree().current_scene.add_child(bullet)
    AudioManager.play_sfx("shoot")
```

**Fragment detekcija** — u sceni, HitArea treba da ima signal:
Dodati u `_ready()`:
```gdscript
var hit_area := get_node_or_null("HitArea") as Area2D
if hit_area:
    hit_area.body_entered.connect(_on_hit_area_body_entered)

func _on_hit_area_body_entered(body: Node2D) -> void:
    if body.is_in_group("other_side_fragments"):
        if overlay:
            overlay.restore(25.0)
        fragment_collected.emit(ai_type)
        body.queue_free()
```

**`die()`**:
```gdscript
func die() -> void:
    if is_dying:
        return
    is_dying = true
    velocity = Vector2.ZERO
    set_physics_process(false)
    ai_died.emit(ai_type)
    AudioManager.play_sfx("enemy_kill")
    # TODO: death animacija
    queue_free()
```

---

### PRIORITET 4 — other_side_manager.gd (dopuniti)

Dodati grupu na `_ready()`:
```gdscript
func _ready() -> void:
    add_to_group("other_side_manager")
    _connect_signals()
```

**`_on_boss_died()`**:
```gdscript
func _on_boss_died() -> void:
    other_side_lost.emit()
    await get_tree().create_timer(1.5).timeout
    # Reuse postojeceg game_over screena
    var go = get_tree().get_first_node_in_group("game_over") # ili direktna referenca
    if go and go.has_method("show_game_over"):
        go.show_game_over(0, 0, "THE BOSS HAS FALLEN", "You were defeated on the other side.")
```

**`_check_win()`**:
```gdscript
func _check_win() -> void:
    if _light_dead and _heavy_dead:
        other_side_won.emit()
        await get_tree().create_timer(1.5).timeout
        var go = get_tree().get_first_node_in_group("game_over")
        if go and go.has_method("show_game_over"):
            go.show_game_over(0, 0, "BOSS WINS", "You are the other side.", true)
```

---

### PRIORITET 5 — other_side_hud.tscn (kreirati u editoru)

Kreirati `scenes/hud/other_side_hud.tscn` sa sledecim Control nodovima:

```
OtherSideHUD (CanvasLayer) ← attach: other_side_hud.gd
├── BossSection (VBoxContainer) — anchor: top-left
│     ├── Label "BOSS"
│     ├── BossHPBar (ProgressBar, max=100)
│     └── BossHPLabel (Label)
├── AISection (HBoxContainer) — anchor: top-right
│     ├── LightGroup (VBoxContainer)
│     │     ├── Label "LIGHT"
│     │     ├── LightHPBar (ProgressBar)
│     │     ├── LightHPLabel (Label)
│     │     ├── LightScreenBar (ProgressBar)
│     │     └── LightScreenLabel (Label)
│     └── HeavyGroup (VBoxContainer)
│           ├── Label "HEAVY"
│           ├── HeavyHPBar (ProgressBar)
│           ├── HeavyHPLabel (Label)
│           ├── HeavyScreenBar (ProgressBar)
│           └── HeavyScreenLabel (Label)
├── AbilitySection (VBoxContainer) — anchor: bottom-left
│     ├── ShrinkLabel (Label, text="SHRINK [SPACE]")
│     ├── ShrinkBar (ProgressBar)
│     ├── SummonLabel (Label, text="SUMMON [SHIFT]")
│     └── SummonBar (ProgressBar)
├── PhaseLabel (Label) — anchor: top-center
└── EMPWarning (Label) — anchor: center, veliki font, pocetno nevidljiv
```

---

## Kako testirati

### Test 1 — ai_screen_overlay (odmah, bez scene)

1. Kreirati novu scenu: `Node2D` kao root
2. Dodati child `Node2D`, attach script `ai_screen_overlay.gd`
3. Dodati GDScript na root koji u `_process` poziva:
   ```gdscript
   $Node2D.apply_shrink(5.0, delta)  # 5% po sekundi
   ```
4. Pokrenuti scenu — treba da vidis pravougaoni okvir koji se suzi

---

### Test 2 — Portal trigger (odmah)

1. Pokrenuti normalnu igru
2. Pobediti bossa (ili koristiti debug skip: `U` taster tokom boss wave-a)
3. Ocekivano: pojavljuje se tekst **"The other side awaits..."** i posle 3s
   pokusava da ucita `other_side.tscn` — bice greska jer scena ne postoji jos,
   ali signal da portal transition radi

---

### Test 3 — Kompletni other_side (posle kreiranja scene)

1. Kreirati `other_side.tscn` prema PRIORITET 1 strukturi
2. Popuniti sve TODO u `player_boss.gd` i `ai_player.gd`
3. U Project Settings → Run → Main Scene: privremeno postaviti `other_side.tscn`
4. Pokrenuti i proveriti:
   - [ ] Boss se krece WASD
   - [ ] Boss puca levim klikom
   - [ ] AI igraci prate bossa
   - [ ] AI igraci pucaju u bossa
   - [ ] Space aktivira shrink (overlay se suzi na oba AI-ja)
   - [ ] AI igraci menjaju prioritet ka fragmentima
   - [ ] Fragmenti se spawnu blizu AI igraca
   - [ ] AI skuplja fragment → overlay se vraca
   - [ ] Shift spawna pixel grunte
   - [ ] Heavy dobija shield (plavi flash) na 75/50/25% HP
   - [ ] Kad Light umre → Heavy Berserk
   - [ ] EMP debuff uspori bossa

---

## Input akcije (vec dodato u project.godot)

| Akcija | Taster |
|--------|--------|
| `boss_shrink` | Space |
| `boss_summon` | Shift |
| `shoot` | Levi klik (reuse) |
| `move_*` | WASD (reuse) |

---

## Poznati problemi koje treba resiti

| Problem | Resenje |
|---------|---------|
| AI bullet pogadja bossa | U `bullet.tscn` (player bullet) collision layer ne udara `player_boss` — proveriti layer maske |
| Boss bullet pogadja AI igraca | `boss_bullet.tscn` collision mask — proveriti da udara layer AI igraca |
| NavigationRegion2D u other_side.tscn | Mora se bake-ovati navigation mesh za AI pathfinding da radi |
| Fragment detekcija | AI HitArea mora biti na odgovarajucem collision layeru |
| `game_over` screen referenca | U manager koristiti direktnu @onready referencu umesto get_first_node_in_group |
