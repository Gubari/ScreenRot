class_name WaveData
extends Resource

## Defines the configuration for a single wave.

@export var wave_name: String = "Wave"
@export var spawn_groups: Array[SpawnGroup] = []
## Distance from camera center at which enemies spawn (in pixels).
## Low values (e.g. 5) = spawn right on the player. 0 = use default (600).
@export var spawn_radius: float = 0.0
## Multiplier for coin drop chance this wave. 1.0 = default, 0.3 = 70% less.
@export_range(0.0, 2.0, 0.05) var coin_drop_rate: float = 1.0
## Multiplier for defrag drop chance this wave. 1.0 = default, 0.6 = 40% less.
@export_range(0.0, 2.0, 0.05) var defrag_drop_rate: float = 1.0
## Percent of max HP restored right after this wave is cleared.
@export_range(0.0, 100.0, 1.0) var post_wave_heal_percent: float = 0.0
## Seconds to wait after this wave is cleared before showing upgrades.
@export_range(0.0, 30.0, 0.1) var post_wave_delay: float = 1.5
## If true, plays the boss cinematic intro before spawning this wave.
@export var is_boss_wave: bool = false
## If true, enemies spawn at the arena center instead of around the player.
@export var spawn_in_center: bool = false
