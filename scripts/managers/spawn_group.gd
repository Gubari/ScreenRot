class_name SpawnGroup
extends Resource

## Defines a single group of enemies to spawn within a wave.

@export_enum("pixel_grunt", "static_walker", "bit_bug", "bloatware_boss") var enemy_type: String = "pixel_grunt"
@export_range(1, 50) var count: int = 1
@export_range(0.0, 30.0, 0.1) var delay_before_spawn: float = 0.0
