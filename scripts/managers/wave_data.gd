class_name WaveData
extends Resource

## Defines the configuration for a single wave.

@export var wave_name: String = "Wave"
@export var spawn_groups: Array[SpawnGroup] = []
## Distance from camera center at which enemies spawn (in pixels).
## Low values (e.g. 5) = spawn right on the player. 0 = use default (600).
@export var spawn_radius: float = 0.0
