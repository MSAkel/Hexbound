class_name ScoreProgression
extends Resource

## Editable score targets for the authored rounds and the Endless Mode curve.

const ENDLESS_MODE_START_ROUND := 10
const MAX_SCORE := 9223372036854775807

@export_group("Rounds 1-9")
@export_range(1, 1000000000, 1, "or_greater") var round_1_score: int = 1000
@export_range(1, 1000000000, 1, "or_greater") var round_2_score: int = 2250
@export_range(1, 1000000000, 1, "or_greater") var round_3_score: int = 4125
@export_range(1, 1000000000, 1, "or_greater") var round_4_score: int = 6937
@export_range(1, 1000000000, 1, "or_greater") var round_5_score: int = 11155
@export_range(1, 1000000000, 1, "or_greater") var round_6_score: int = 17482
@export_range(1, 1000000000, 1, "or_greater") var round_7_score: int = 26973
@export_range(1, 1000000000, 1, "or_greater") var round_8_score: int = 41209
@export_range(1, 1000000000, 1, "or_greater") var round_9_score: int = 62563

@export_group("Endless Mode")
## Multiplier used by the curve. Values above 1 increase the target every round.
@export_range(1.01, 10.0, 0.01, "or_greater") var endless_growth_factor: float = 1.5
## Values above 1 make the exponent itself accelerate, producing superexponential growth.
@export_range(1.01, 3.0, 0.01, "or_greater") var endless_growth_power: float = 1.15


func get_required_score(round_number: int) -> int:
	match round_number:
		1: return round_1_score
		2: return round_2_score
		3: return round_3_score
		4: return round_4_score
		5: return round_5_score
		6: return round_6_score
		7: return round_7_score
		8: return round_8_score
		9: return round_9_score

	var endless_round := maxi(1, round_number - ENDLESS_MODE_START_ROUND + 1)
	var exponent := pow(float(endless_round), endless_growth_power)
	var scaled_score := float(round_9_score) * pow(endless_growth_factor, exponent)
	if is_inf(scaled_score) or scaled_score >= MAX_SCORE:
		return MAX_SCORE
	return maxi(1, roundi(scaled_score))
