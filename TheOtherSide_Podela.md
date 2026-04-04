# THE OTHER SIDE — Podela rada

## Pregled

Posle boss defeata otvara se debris portal. Igrač ulazi i prelazi na drugu stranu —
kontroliše Anihilatora i bori se protiv dva AI igrača (Light i Heavy).

---

## Signali — dogovoriti PRE početka

Ovo je interfejs između svih sistema. Svako emituje i sluša prema tabeli ispod.

```
# player_boss.gd emituje:
signal boss_damaged(current_hp: int, max_hp: int)
signal phase_changed(phase: int)          # 1, 2 ili 3
signal shrink_activated()                 # Space pritisnut, cd prošao
signal wave_summoned()                    # Shift pritisnut, cd prošao

# ai_player.gd emituje:
signal ai_died(ai_type: String)           # "light" ili "heavy"
signal ai_damaged(current_hp: int, max_hp: int, ai_type: String)
signal emp_hit_boss()                     # EMP pogodio bossa
signal fragment_collected(ai_type: String)

# other_side_manager.gd emituje:
signal shrink_started(duration: float)
signal shrink_stopped()
signal partner_died(ai_type: String)      # ka preživelom AI-ju
signal other_side_won()
signal other_side_lost()
```

---

## OSOBA 1 — AI Igrači

**Fajlovi:**
```
scripts/other_side/ai_screen_overlay.gd   ← kompletno implementirano
scripts/other_side/ai_player.gd           ← skeleton, popuniti
scenes/other_side/ai_light.tscn
scenes/other_side/ai_heavy.tscn
```

### ai_screen_overlay.gd — već implementirano

Node2D child na svakom AI igraču. Crta viewport okvir (192×128px) koji se suži
od svih 4 strane. Boja: zelena → žuta → crvena po stanju.

Javni API:
```gdscript
var screen_percent: float = 100.0
func apply_shrink(rate: float, delta: float) -> void
func restore(amount: float) -> void
func get_screen_percent() -> float
```

### ai_player.gd — popuniti

State machine: `CHASE → SHOOT → COLLECT → EMP_WINDUP → SHIELDED`

**Export varijable (razlikuju se u Light i Heavy sceni):**
```
ai_type: String         # "light" ili "heavy"
max_hp: int             # Light: 8 | Heavy: 18
move_speed: float       # Light: 180 | Heavy: 100
fire_rate: float        # Light: 0.4 | Heavy: 0.7
has_dash: bool          # Light: true | Heavy: false
emp_cooldown: float     # Light: 12s | Heavy: 18s
```

**Mehanike za implementirati:**
1. **Panic mode** — kad `shrink_started` signal stigne, State → COLLECT,
   navigira ka fragmentu iz grupe `"other_side_fragments"`, puca 2× sporije.
   Kad skupi fragment: `overlay.restore(25.0)`, emituje `fragment_collected`.

2. **Defrag EMP** — kad cooldown istekne i boss u radijusu 250px:
   State → EMP_WINDUP (0.8s telegraphing), zatim emituje `emp_hit_boss`.

3. **Heavy Shield** — na svakih 25% izgubljenog HP, `is_shielded = true` 3s,
   plavi flash, metci se ignorišu.

4. **Berserk** — kad `partner_died` signal stigne:
   `move_speed *= 1.5`, `fire_rate *= 0.6`
   Light bonus: `dash_cooldown *= 0.5`

---

## OSOBA 2 — Player Boss

**Fajlovi:**
```
scripts/other_side/player_boss.gd   ← skeleton, popuniti
scenes/other_side/player_boss.tscn
```

Reuse: `boss_bullet.tscn`, `pixel_grunt.tscn`

**Faze po HP:**
```
Phase 1 (HP > 60%): single shot,  shrink CD 20s
Phase 2 (HP 30-60%): spread 3,    shrink CD 15s
Phase 3 (HP < 30%): spread 5,     shrink CD 10s, fire_rate +30%
```

**Metode za implementirati:**
- `handle_movement()` — WASD, move_speed 130
- `handle_shooting(delta)` — lijevi klik, spread po fazi
- `activate_shrink()` — Space, cooldown check, emituje `shrink_activated`
- `summon_wave()` — Shift, cooldown check, emituje `wave_summoned`
- `apply_emp_debuff()` — poziva manager, fire_rate i speed debuff 3s
- `_check_phase()` — po HP procentu, emituje `phase_changed`

---

## OSOBA 3 — Scena i Manager

**Fajlovi:**
```
scenes/other_side.tscn
scripts/other_side/other_side_manager.gd   ← skeleton, popuniti
```
**Modifikuje:**
```
scripts/managers/game_manager.gd  →  _on_boss_defeated()
```

### other_side.tscn — node struktura
```
other_side (Node2D)
├── OtherSideManager
├── DungeonMap          ← reuse
├── PlayerBoss
├── AILight
├── AIHeavy
├── EnemySpawner        ← reuse za summon wave
├── HUD (other_side_hud.tscn)
└── ScreenClosing       ← reuse (samo za vizual shrinka na AI overlayima)
```

### other_side_manager.gd — popuniti

**Shrink logika:**
- Kad `shrink_activated` stigne: pokreće shrink na oba AI overlaya,
  spawna 3 fragmenta blizu svakog AI igrača (grupa `"other_side_fragments"`),
  emituje `shrink_started(6.0)`. Posle 6s: emituje `shrink_stopped`.

**Summon:**
- Kad `wave_summoned` stigne: `enemy_spawner.add_spawning([{type: pixel_grunt, count: 4}])`

**Win/Loss:**
- Kad oba AI umru → `other_side_won.emit()`
- Kad boss HP = 0 → `other_side_lost.emit()`

**game_manager.gd modifikacija:**
```gdscript
func _on_boss_defeated(_boss_id: String, _score: int) -> void:
    # ... postojeći kod ...
    await _show_portal_and_enter()

func _show_portal_and_enter() -> void:
    gameplay_hud.show_wave("The other side awaits...")
    await get_tree().create_timer(3.0).timeout
    SceneTransition.change_scene("res://scenes/other_side.tscn")
```

---

## OSOBA 4 — HUD, Integracija, Balansiranje

**Fajlovi:**
```
scripts/hud/other_side_hud.gd      ← skeleton, popuniti
scenes/hud/other_side_hud.tscn
```

### other_side_hud.gd — popuniti

**Prikazuje:**
- Boss HP bar (crvena) — levo gore
- Light HP + screen% bar — desno gore
- Heavy HP + screen% bar — desno gore (ispod Light)
- Space cooldown bar — dole levo
- Shift cooldown bar — dole levo
- Phase label ("PHASE 1/2/3") — centar gore
- EMP warning flash ("! EMP !") — centar

**Metode za implementirati:**
```gdscript
func update_boss_hp(current: int, max_hp: int) -> void
func update_ai_hp(ai_type: String, current: int, max_hp: int) -> void
func update_screen_percent(ai_type: String, percent: float) -> void
func update_shrink_cooldown(percent: float) -> void
func update_summon_cooldown(percent: float) -> void
func show_phase(phase: int) -> void
func flash_emp_warning() -> void
```

**Integracija (kad Osobe 1, 2, 3 završe):**
- Wire-up svih signala u `other_side.tscn`
- Testiranje i balansiranje vrednosti

---

## Balansiranje (menjati posle playtesta)

| Parametar | Vrednost |
|-----------|----------|
| Boss HP | 25 |
| Light HP | 8 |
| Heavy HP | 18 |
| Shrink trajanje | 6s |
| Shrink rate (% / s) | 10 |
| Fragmenta po AI | 3 |
| Fragment restore | 25% |
| EMP debuff trajanje | 3s |
| Heavy shield trajanje | 3s |
| Summon CD | 18s |
| Boss move_speed | 130 |
| Light move_speed | 180 |
| Heavy move_speed | 100 |

---

## Napomene

- `screen_fragment.tscn` se reuse-uje — dodati `"other_side_fragments"` grupu
- `enemy_spawner.gd` se reuse-uje za summon (`add_spawning()` već postoji)
- Dungeon mapa identična, samo drugačiji color modulate na tilesetu
- Skeleton fajlovi su već kreirani u `scripts/other_side/` — svako popunjava svoje
