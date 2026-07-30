extends Resource
class_name PlayerCharacter

enum Type {
	PEASANT,
	GREEDY_LORD,
}

const BASIC_RUNE := preload("uid://c7c2eo74m8q0l")
const GOLD_SINK := preload("uid://oh25j7sj0pf0")

# Build the starting hand runes for the given character type
static func get_starting_hand_runes(character_type: Type) -> Array[Rune]:
	var hand: Array[Rune] = []

	match character_type:
		Type.PEASANT:
			hand.append(BASIC_RUNE)
			hand.append(BASIC_RUNE)
			hand.append_array(_get_random_common_runes(3))
		Type.GREEDY_LORD:
			hand.append(BASIC_RUNE)
			hand.append(BASIC_RUNE)
			hand.append(GOLD_SINK)
			hand.append(GOLD_SINK)
			hand.append_array(_get_random_common_runes(1))

	return hand


# Pick random common runes from the pool, excluding character-specific starter cards
static func _get_random_common_runes(count: int) -> Array[Rune]:
	var excluded_ids := [BASIC_RUNE.id, GOLD_SINK.id]
	var pool: Array[Rune] = []

	for rune in GameManager.runes_pool:
		if rune.id in excluded_ids:
			continue
		if rune.rarity == Rune.RuneRarity.COMMON:
			pool.append(rune)

	pool.shuffle()

	var result: Array[Rune] = []
	for i in mini(count, pool.size()):
		result.append(pool[i])

	return result


static func get_starting_gold(character_type: Type) -> int:
	match character_type:
		Type.PEASANT:
			return 10
		Type.GREEDY_LORD:
			return 25

	return 10

static func get_character_name(character_type: Type) -> String:
	match character_type:
		Type.PEASANT:
			return "The Peasant"
		Type.GREEDY_LORD:
			return "The Greedy Lord"

	return "Unknown"