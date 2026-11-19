class_name ScoreProgression
extends Object

## Authored round targets and the Endless Mode curve. One table for the whole game.

## Days in a standard run. Clearing the last one wins. Endless Mode starts after it.
const RUN_LENGTH_ROUNDS := 9
const ENDLESS_MODE_START_ROUND := RUN_LENGTH_ROUNDS + 1
const MAX_SCORE := 9223372036854775807
## One entry per round of a standard run, indexed as AUTHORED_ROUND_SCORES[round - 1].
## These are the Level 1 (practice) targets; Levels 2 and 6 ramp them up by Day.
## Nov 2026 (untuned): Day 1 475 and Day 2 2400 (approved) so Days 1-2 are for building the board,
## then Days 2-9 about 15% below the earlier 3200/8500/18k/34k/47k/92k/135k/150k table so Level 1
## works as a practice and learning level. Day 7 smoothed from 78k to 65k (untuned): Day 6 -> 7 was
## the steepest step (x1.95, now x1.63).
const AUTHORED_ROUND_SCORES: Array[int] = [
	475,
	2040,
	7200,
	15300,
	28900,
	40000,
	65000,
	115000,
	127500,
]
## Multiplier used by the endless curve. Values above 1 increase the target every round.
const ENDLESS_GROWTH_FACTOR := 1.5
## Values above 1 make the exponent itself accelerate, producing superexponential growth.
const ENDLESS_GROWTH_POWER := 1.15


## Day target for round_number, scaled by the difficulty's target multiplier.
static func get_required_score(
	round_number: int,
	difficulty: Difficulty.Level = Difficulty.Level.LEVEL_1
) -> int:
	var base_score := _get_base_required_score(round_number)
	var scale := Difficulty.get_score_target_multiplier(difficulty, round_number)
	if is_equal_approx(scale, 1.0) or base_score >= MAX_SCORE:
		return base_score
	var scaled_score := float(base_score) * scale
	if scaled_score >= MAX_SCORE:
		return MAX_SCORE
	return roundi(scaled_score)


static func _get_base_required_score(round_number: int) -> int:
	if round_number >= 1 and round_number <= AUTHORED_ROUND_SCORES.size():
		return AUTHORED_ROUND_SCORES[round_number - 1]

	var endless_round := maxi(1, round_number - ENDLESS_MODE_START_ROUND + 1)
	var exponent := pow(float(endless_round), ENDLESS_GROWTH_POWER)
	var round_9_score := AUTHORED_ROUND_SCORES[AUTHORED_ROUND_SCORES.size() - 1]
	var scaled_score := float(round_9_score) * pow(ENDLESS_GROWTH_FACTOR, exponent)
	if is_inf(scaled_score) or scaled_score >= MAX_SCORE:
		return MAX_SCORE
	return maxi(1, roundi(scaled_score))
