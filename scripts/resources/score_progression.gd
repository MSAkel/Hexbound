class_name ScoreProgression
extends Object

## Authored round targets and the Endless Mode curve. One table for the whole game.

const ENDLESS_MODE_START_ROUND := 10
const MAX_SCORE := 9223372036854775807
## Round 1 through 9, indexed as AUTHORED_ROUND_SCORES[round - 1].
const AUTHORED_ROUND_SCORES: Array[int] = [
	435,
	1200,
	3600,
	6800,
	11155,
	17500,
	27000,
	41200,
	60000,
]
## Multiplier used by the endless curve. Values above 1 increase the target every round.
const ENDLESS_GROWTH_FACTOR := 1.5
## Values above 1 make the exponent itself accelerate, producing superexponential growth.
const ENDLESS_GROWTH_POWER := 1.15


static func get_required_score(round_number: int) -> int:
	if round_number >= 1 and round_number <= AUTHORED_ROUND_SCORES.size():
		return AUTHORED_ROUND_SCORES[round_number - 1]

	var endless_round := maxi(1, round_number - ENDLESS_MODE_START_ROUND + 1)
	var exponent := pow(float(endless_round), ENDLESS_GROWTH_POWER)
	var round_9_score := AUTHORED_ROUND_SCORES[AUTHORED_ROUND_SCORES.size() - 1]
	var scaled_score := float(round_9_score) * pow(ENDLESS_GROWTH_FACTOR, exponent)
	if is_inf(scaled_score) or scaled_score >= MAX_SCORE:
		return MAX_SCORE
	return maxi(1, roundi(scaled_score))
