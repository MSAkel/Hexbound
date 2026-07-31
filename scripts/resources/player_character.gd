extends Resource
class_name PlayerCharacter

# Each playable selection is tied to a fixed trigger order for the entire run.
enum Type {
	SURVEYOR,
	ENCIRCLER,
	SPIRALIST,
}

const BASIC_RUNE := preload("uid://c7c2eo74m8q0l")

static func get_all_types() -> Array[Type]:
	return [
		Type.SURVEYOR,
		Type.ENCIRCLER,
		Type.SPIRALIST,
	]


static func get_trigger_order(character_type: Type) -> TriggerOrderType.Type:
	match character_type:
		Type.SURVEYOR:
			return TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT
		Type.ENCIRCLER:
			return TriggerOrderType.Type.OUTER_RING_TO_INNER
		Type.SPIRALIST:
			return TriggerOrderType.Type.CLOCKWISE_SPIRAL
		_:
			return TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT


# Build the starting hand runes for the given character type.
# Unique per-character rune sets are not finalized yet.
static func get_starting_hand_runes(character_type: Type) -> Array[Rune]:
	var hand: Array[Rune] = []

	match character_type:
		Type.SURVEYOR, Type.ENCIRCLER, Type.SPIRALIST:
			hand.append(BASIC_RUNE)
			hand.append(BASIC_RUNE)
			hand.append_array(_get_random_common_runes(3))

	return hand


# Pick random common runes from the pool, excluding character-specific starter cards.
static func _get_random_common_runes(count: int) -> Array[Rune]:
	var excluded_ids := [BASIC_RUNE.id]
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
		Type.SURVEYOR, Type.ENCIRCLER, Type.SPIRALIST:
			return 10

	return 10


static func get_character_name(character_type: Type) -> String:
	match character_type:
		Type.SURVEYOR:
			return "The Surveyor"
		Type.ENCIRCLER:
			return "The Encircler"
		Type.SPIRALIST:
			return "The Spiralist"

	return "Unknown"


# Passive abilities are not finalized yet
static func get_passive_description(character_type: Type) -> String:
	match character_type:
		Type.SURVEYOR, Type.ENCIRCLER, Type.SPIRALIST:
			return "Passive ability: TBD"

	return "Unknown"
