class_name WaveManager
extends Node

## Manages wave configuration. Add WaveData resources to the waves array
## in the Inspector to define enemy spawn patterns for each wave.
##
## In Classic mode, plays the configured waves in order.
## In Challenge mode, generates endless waves with incrementally scaling difficulty.

@export var waves: Array[WaveData] = []
@export var is_endless_mode: bool = false
## Default distance from camera center at which enemies spawn (in pixels).
## Used when a WaveData doesn't set its own spawn_radius.
@export var default_spawn_radius: float = 600.0
## Node2D whose position is used as the arena center for boss/center spawning.
## Drop BossCenter node here directly from the Scene panel.
@export var spawn_center_node: Node2D = null

## Enemy types available for challenge mode procedural waves (no boss).
const CHALLENGE_ENEMY_TYPES: Array[String] = ["pixel_grunt", "static_walker", "bit_bug", "toxic_fly"]

## Base enemy count for challenge mode wave 1.
const CHALLENGE_BASE_COUNT: int = 8
## How many extra enemies per wave in challenge mode.
const CHALLENGE_COUNT_INCREMENT: int = 3
## Max enemy types unlocked gradually (1 type at wave 1, all 4 by wave 4+).
const CHALLENGE_TYPE_UNLOCK_RATE: int = 1

## Converts a WaveData resource into the spawn queue format
## that EnemySpawner expects: [{"type", "count", "delay"}]
## where delay is an absolute timestamp in seconds from wave start.
func get_wave_data(wave_number: int) -> Array:
	if is_endless_mode:
		return _generate_challenge_wave(wave_number)

	if waves.is_empty():
		push_warning("WaveManager: No waves configured!")
		return []

	var index := wave_number - 1

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

func get_wave_name(wave_number: int) -> String:
	if is_endless_mode:
		return "Wave " + str(wave_number)

	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	if not waves.is_empty() and waves[index].wave_name != "":
		return waves[index].wave_name
	return "Wave " + str(wave_number)

func get_spawn_radius(wave_number: int) -> float:
	if is_endless_mode:
		return default_spawn_radius

	if waves.is_empty():
		return default_spawn_radius
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	var wave: WaveData = waves[index]
	if wave.spawn_radius > 0.0:
		return wave.spawn_radius
	return default_spawn_radius

func has_next_wave(current_wave: int) -> bool:
	if is_endless_mode:
		return true
	return current_wave < waves.size()

func get_total_waves() -> int:
	if is_endless_mode:
		return -1  # infinite
	return waves.size()

## Returns the coin drop rate multiplier for the given wave.
func get_coin_drop_rate(wave_number: int) -> float:
	if is_endless_mode:
		return 0.3  # 70% reduction in endless mode
	if waves.is_empty():
		return 1.0
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].coin_drop_rate

## Returns the defrag drop rate multiplier for the given wave.
func get_defrag_drop_rate(wave_number: int) -> float:
	if is_endless_mode:
		if wave_number > 9:
			return 0.6  # 40% reduction after wave 9
		return 1.0
	if waves.is_empty():
		return 1.0
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].defrag_drop_rate

## Returns the post-wave delay for the given wave.
func get_post_wave_delay(wave_number: int) -> float:
	if is_endless_mode:
		return 1.5
	if waves.is_empty():
		return 1.5
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].post_wave_delay

## Returns how much HP (in % of max HP) is restored when this wave is cleared.
## Returns whether this wave spawns enemies at a fixed center point.
func get_spawn_in_center(wave_number: int) -> bool:
	if is_endless_mode or waves.is_empty():
		return false
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].spawn_in_center

## Returns the world position to use as spawn center for the given wave, or Vector2.ZERO if not set.
func get_spawn_center_position(wave_number: int) -> Vector2:
	if is_endless_mode or waves.is_empty():
		return Vector2.ZERO
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	var wave: WaveData = waves[index]
	if not wave.spawn_in_center:
		return Vector2.ZERO
	if spawn_center_node and is_instance_valid(spawn_center_node):
		return spawn_center_node.global_position
	return Vector2.ZERO

## Returns whether this wave triggers the boss cinematic intro.
func get_is_boss_wave(wave_number: int) -> bool:
	if is_endless_mode or waves.is_empty():
		return false
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].is_boss_wave

func get_post_wave_heal_percent(wave_number: int) -> float:
	if is_endless_mode:
		return 0.0
	if waves.is_empty():
		return 0.0
	var index := clampi(wave_number - 1, 0, waves.size() - 1)
	return waves[index].post_wave_heal_percent

## Generates a procedural wave for challenge/endless mode.
## Enemies scale up incrementally each wave. New enemy types unlock gradually.
func _generate_challenge_wave(wave_number: int) -> Array:
	var queue: Array = []

	# Total enemy budget for this wave
	var total_enemies: int = CHALLENGE_BASE_COUNT + (wave_number - 1) * CHALLENGE_COUNT_INCREMENT

	# How many enemy types are unlocked (1 at wave 1, +1 per wave, max all)
	var unlocked_count: int = clampi(wave_number, 1, CHALLENGE_ENEMY_TYPES.size())
	var available_types: Array[String] = []
	for i in unlocked_count:
		available_types.append(CHALLENGE_ENEMY_TYPES[i])

	# Distribute enemies across available types
	@warning_ignore("integer_division")
	var per_type: int = total_enemies / available_types.size()
	var remainder: int = total_enemies % available_types.size()

	# Absolute timestamps from wave start.
	for i in available_types.size():
		var count: int = per_type + (1 if i < remainder else 0)
		if count <= 0:
			continue
		var delay: float = 0.0 if i == 0 else (i * 1.5)
		queue.append({
			"type": available_types[i],
			"count": count,
			"delay": delay,
		})

	# Every 3rd wave, add a second reinforcement group with a longer delay
	if wave_number >= 3 and wave_number % 3 == 0:
		@warning_ignore("integer_division")
		var reinforcement_count: int = clampi(wave_number / 2, 3, 25)
		var reinforcement_type: String = available_types[randi() % available_types.size()]
		queue.append({
			"type": reinforcement_type,
			"count": reinforcement_count,
			"delay": 5.0,
		})

	return queue
