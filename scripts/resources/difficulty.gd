extends Resource
class_name Difficulty

# Static difficulty definitions and helpers, mirroring the PlayerCharacter pattern.

enum Level {
	LEVEL_0,
	LEVEL_1,
	LEVEL_2,
	LEVEL_3,
	LEVEL_4,
}

# Other difficulty ideas:
# level 6 - At the start of every new round, two production runes are cursed, 
# Cursed runes produce negative values until the next round.
# each turn, a card in your hand becomes unplayable
const DIFFICULTY_INFO = {
	Level.LEVEL_0: {
		"name": "Level 1",
		"info": "Base difficulty",
	},
	Level.LEVEL_1: {
		"name": "Level 2",
		"info": "Start with 1 fewer support card in your starting hand",
	},
	Level.LEVEL_2: {
		"name": "Level 3",
		"info": "start with 0 gold",
	},
	Level.LEVEL_3: {
		"name": "Level 4",
		"info": "merchant prices are 20% higher",
	},
	Level.LEVEL_4: {
		"name": "Level 5",
		"info": "Three random tiles are disabled for the entire run.",
	},
}


static func get_all_levels() -> Array[Level]:
	return [
		Level.LEVEL_0,
		Level.LEVEL_1,
		Level.LEVEL_2,
		Level.LEVEL_3,
		Level.LEVEL_4,
	]


static func get_level_name(level: Level) -> String:
	return DIFFICULTY_INFO[level]["name"]


static func get_level_info(level: Level) -> String:
	return DIFFICULTY_INFO[level]["info"]


# How many starting-hand cards to remove for the given difficulty.
static func get_starting_hand_reduction(level: Level) -> int:
	if level >= Level.LEVEL_1:
		return 1
	return 0

static func get_starting_gold(level: Level) -> int:
	return 0 if level >= Level.LEVEL_2 else 10

static func get_merchant_price_multiplier(level: Level) -> float:
	return 1.2 if level >= Level.LEVEL_3 else 1.0


# How many map tiles are permanently disabled for the entire run.
static func get_disabled_tile_count(level: Level) -> int:
	return 3 if level >= Level.LEVEL_4 else 0
