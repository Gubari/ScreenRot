extends Object
class_name MovementFormula
## Jedinstvena formula: brzina = max(0, base × multiplier); velocity = normalizovan_smer × ta vrednost.
##
## `move_speed` na playeru i na enemy-ju = ista stvar: cilj u svetskim px/s. Ako oba imaju npr. 250,
## maksimalna brzina hoda je ista (enemy RVO se klešti na taj maksimum, ne iznad).

static func scalar(base_move_speed: float, multiplier: float = 1.0) -> float:
	return maxf(base_move_speed * multiplier, 0.0)


static func velocity(unit_direction: Vector2, base_move_speed: float, multiplier: float = 1.0) -> Vector2:
	if unit_direction.length_squared() < 1e-8:
		return Vector2.ZERO
	return unit_direction.normalized() * scalar(base_move_speed, multiplier)
