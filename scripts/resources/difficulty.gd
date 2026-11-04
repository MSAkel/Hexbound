extends Resource
class_name Difficulty

## Difficulty levels and the rule each one adds. Levels stack: a level keeps every rule below it.
## Numbers are untuned.

enum Level {
	LEVEL_1,
	LEVEL_2,
	LEVEL_3,
	LEVEL_4,
	LEVEL_5,
	LEVEL_6,
}

const DIFFICULTY_INFO = {
	Level.LEVEL_1: {
		"name": "Level 1",
		"info": "Base difficulty.",
	},
	Level.LEVEL_2: {
		"name": "Level 2",
		"info": "Day targets are 15% higher.",
	},
	Level.LEVEL_3: {
		"name": "Level 3",
		"info": "2 free card rerolls per Day instead of 3.",
	},
	Level.LEVEL_4: {
		"name": "Level 4",
		"info": "Start with 5 less Gold.",
	},
	Level.LEVEL_5: {
		"name": "Level 5",
		"info": "Each Station level needs 1 more Meal served.",
	},
	Level.LEVEL_6: {
		"name": "Level 6",
		"info": "The Merchant shows 1 fewer card.",
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
	]


static func get_level_name(level: Level) -> String:
	return DIFFICULTY_INFO[level]["name"]


static func get_level_info(level: Level) -> String:
	return DIFFICULTY_INFO[level]["info"]


## Level 2. Day target multiplier, applied to authored and Endless targets alike.
static func get_score_target_multiplier(level: Level) -> float:
	return 1.15 if level >= Level.LEVEL_2 else 1.0


## Level 3. Free card-pick rerolls lost each Day.
static func get_free_reroll_reduction(level: Level) -> int:
	return 1 if level >= Level.LEVEL_3 else 0


## Level 4. Gold removed from the run's starting Gold (base or chef).
static func get_starting_gold_reduction(level: Level) -> int:
	return 5 if level >= Level.LEVEL_4 else 0


## Level 5. Extra Meals each Station level costs. Applied per step, so the nth level-up
## needs n more Meals served in total than it would otherwise.
static func get_station_level_extra_meals(level: Level) -> int:
	return 1 if level >= Level.LEVEL_5 else 0


## Level 6. Tile card slots removed from the Merchant shelf. The Technique slot is kept.
static func get_merchant_tile_slot_reduction(level: Level) -> int:
	return 1 if level >= Level.LEVEL_6 else 0
