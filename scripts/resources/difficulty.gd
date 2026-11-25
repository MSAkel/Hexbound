extends Resource
class_name Difficulty

## Difficulty levels and the rule each one adds. Levels stack: a level keeps every rule below it.
## Level 1 is the most generous form of the game; some levels bring back a base restriction.
## Numbers are untuned.

## 8 levels (user, Nov 24: the old Level 3, 5 less starting Gold, is removed and the levels above it
## moved down one). With no end-of-Day card pick the old "-1 card reroll" rule had nothing to act on,
## so Level 3 now takes a hand discard instead. Levels 4 and 7 (Meal slot locks) and 8 (extra Meals
## per Station level) only act while StationManager.LEVELING_ENABLED is true.
enum Level {
	LEVEL_1,
	LEVEL_2,
	LEVEL_3,
	LEVEL_4,
	LEVEL_5,
	LEVEL_6,
	LEVEL_7,
	LEVEL_8,
}

const DIFFICULTY_INFO = {
	Level.LEVEL_1: {
		"name": "Level 1",
		"info": "Base difficulty.",
	},
	Level.LEVEL_2: {
		"name": "Level 2",
		"info": "Day targets are higher",
	},
	Level.LEVEL_3: {
		"name": "Level 3",
		"info": "-1 hand discard each Day.",
	},
	Level.LEVEL_4: {
		"name": "Level 4",
		"info": "2 Stations open their second Meal Slot at level 3.",
	},
	Level.LEVEL_5: {
		"name": "Level 5",
		"info": "Day targets are higher",
	},
	Level.LEVEL_6: {
		"name": "Level 6",
		"info": "Merchant rerolls cost 1 more Gold each time.",
	},
	Level.LEVEL_7: {
		"name": "Level 7",
		"info": "All Stations open their second Meal Slot at level 3.",
	},
	Level.LEVEL_8: {
		"name": "Level 8",
		"info": "Each Station level needs 1 more Meal served.",
	},
}

const BASE_STARTING_GOLD := 5


static func get_all_levels() -> Array[Level]:
	return [
		Level.LEVEL_1,
		Level.LEVEL_2,
		Level.LEVEL_3,
		Level.LEVEL_4,
		Level.LEVEL_5,
		Level.LEVEL_6,
		Level.LEVEL_7,
		Level.LEVEL_8,
	]


## Old run history can hold a level from the 9-level table; it shows by number.
static func get_level_name(level: Level) -> String:
	if not DIFFICULTY_INFO.has(level):
		return "Level %d" % (int(level) + 1)
	return DIFFICULTY_INFO[level]["name"]


static func get_level_info(level: Level) -> String:
	if not DIFFICULTY_INFO.has(level):
		return ""
	return DIFFICULTY_INFO[level]["info"]


## Day target growth per Day after Day 1, added by Level 2 and again by Level 5. Day 1 is the same
## at every level so no one loses the first Day to difficulty. Untuned.
const LEVEL_2_TARGET_GROWTH_PER_DAY := 0.02
const LEVEL_5_TARGET_GROWTH_PER_DAY := 0.03


## Levels 2 and 5. Day target multiplier for round_number. Ramps by Day: Day 1 x1, then each later
## Day adds the growth of every unlocked level (Level 8 Day 9: x1.16 x x1.24). Endless rounds keep
## the Day 9 multiplier.
static func get_score_target_multiplier(level: Level, round_number: int = 1) -> float:
	var days_after_first := clampi(round_number, 1, ScoreProgression.RUN_LENGTH_ROUNDS) - 1
	var multiplier := 1.0
	if level >= Level.LEVEL_2:
		multiplier *= 1.0 + LEVEL_2_TARGET_GROWTH_PER_DAY * float(days_after_first)
	if level >= Level.LEVEL_5:
		multiplier *= 1.0 + LEVEL_5_TARGET_GROWTH_PER_DAY * float(days_after_first)
	return multiplier


## No level takes starting Gold any more (the old Level 3 was removed). Kept for the Gold setup.
static func get_starting_gold_reduction(_level: Level) -> int:
	return 0


## No level takes card-pick rerolls any more (there is no end-of-Day card pick).
static func get_free_reroll_reduction(_level: Level) -> int:
	return 0


## Level 3. Hand discards lost each Day (DeckManager.HAND_DISCARDS_PER_DAY). Untuned.
static func get_hand_discard_reduction(level: Level) -> int:
	return 1 if level >= Level.LEVEL_3 else 0


## Levels 4 and 7. Stations whose second Meal slot stays locked until Station level 3.
## Which stations is rolled per run (StationManager).
static func get_locked_meal_slot_station_count(level: Level) -> int:
	if level >= Level.LEVEL_7:
		return 4
	if level >= Level.LEVEL_4:
		return 2
	return 0


## Level 6. Gold added to the Merchant reroll price after each reroll in a visit. 0 keeps it flat.
static func get_merchant_reroll_cost_step(level: Level) -> int:
	return 1 if level >= Level.LEVEL_6 else 0


## Level 8. Extra Meals each Station level costs. Applied per step, so the nth level-up
## needs n more Meals served in total than it would otherwise.
static func get_station_level_extra_meals(level: Level) -> int:
	return 1 if level >= Level.LEVEL_8 else 0
