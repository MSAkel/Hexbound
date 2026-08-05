extends Resource
class_name PlayerCharacter

# Each playable selection is tied to a fixed trigger order for the entire run.
enum Type {
	SURVEYOR,
	ENCIRCLER,
	SPIRALIST,
}

const BASIC_RUNE := preload("uid://c7c2eo74m8q0l")
const CHAIN_EFFECT = preload("uid://bms421c4eq14w")
const BASIC_MULTI = preload("uid://1yngk6bgvs8i")
const BASIC_ALLOWANCE = preload("uid://dh6iq7pfm421c")
const CATALYST = preload("uid://tgx0mcgx7sat")


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
			hand.append(BASIC_ALLOWANCE)
			hand.append(BASIC_MULTI)
			hand.append(CHAIN_EFFECT)
			hand.append(CATALYST)

	# Drop card based on difficulty level
	var reduction := Difficulty.get_starting_hand_reduction(GameManager.selected_difficulty)
	for _i in reduction:
		if hand.is_empty():
			break
		hand.pop_back()

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
	return Difficulty.get_starting_gold(GameManager.selected_difficulty)

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


static func get_segment_passive_name(character_type: Type) -> String:
	match character_type:
		Type.SURVEYOR:
			return "Row Passive"
		Type.ENCIRCLER:
			return "Circle Passive"
		Type.SPIRALIST:
			return "Center Tile Passive"

	return "Unknown"


static func get_segment_passive_description(character_type: Type) -> String:
	match character_type:
		Type.SURVEYOR:
			return "Every production rune on the first tile of a row segment has double production."
		Type.ENCIRCLER:
			return "If the first rune on a circle segment is a support rune, the rune gains a 15% chance to trigger each prod rune on the same segment."
		Type.SPIRALIST:
			return "Rune in the center tile triggers thrice, including support runes."

	return "Unknown"


static func get_segment_passive_texture(character_type: Type) -> Texture2D:
	match character_type:
		Type.SURVEYOR:
			return preload("res://assets/map/segment_passives/surveyor_segment_passive_map.png")
		Type.ENCIRCLER:
			return preload("res://assets/map/segment_passives/encricler_segment_passive_map.png")
		Type.SPIRALIST:
			return preload("res://assets/map/segment_passives/spiralist_segment_passive_map.png")

	return preload("res://assets/map/segment_passives/surveyor_segment_passive_map.png")
