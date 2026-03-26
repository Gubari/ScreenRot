class_name WaveManager
extends Node

## Manages wave configuration. Add WaveData resources to the waves array
## in the Inspector to define enemy spawn patterns for each wave.
##
## If a wave number exceeds the configured waves, the last wave's data
## is reused as a fallback (endless mode friendly).

@export var waves: Array[WaveData] = []
@export var is_endless_mode: bool = false

## Converts a WaveData resource into the spawn queue format
## that EnemySpawner expects: [{"type": String, "count": int, "delay": float}]
func get_wave_data(wave_number: int) -> Array:
	if waves.is_empty():
		push_warning("WaveManager: No waves configured!")
		return []

	var index := wave_number - 1

	if is_endless_mode:
		# Endless: reuse last wave when we run out
		index = clampi(index, 0, waves.size() - 1)
	else:
		# Fixed: return empty if wave exceeds configured count
		if index < 0 or index >= waves.size():
			return []

	var wave: WaveData = waves[index]
	var queue: Array = []

	for group in wave.spawn_groups:
		queue.append({
			"type": group.enemy_type,
			"count": group.count,
			"delay": group.delay_before_spawn,
		})

	return queue

func has_next_wave(current_wave: int) -> bool:
	if is_endless_mode:
		return true
	return current_wave < waves.size()

func get_total_waves() -> int:
	return waves.size()
