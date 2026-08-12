extends Resource
class_name PlayerCharacter

# Each playable selection is tied to a fixed trigger order for the entire run.
enum Type {
	SURVEYOR,
	ENCIRCLER,
	SPIRALIST,
}

#const RANDOM_SELECTION = preload("uid://dfs3j40u078c6")


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
# 5 random common cards: 3 production (at least one score) and 2 support.
static func get_starting_hand_runes(character_type: Type) -> Array[Rune]:
	var hand: Array[Rune] = []

	match character_type:
		Type.SURVEYOR, Type.ENCIRCLER, Type.SPIRALIST:
			hand.append_array(_get_starting_producer_runes(3))
			hand.append_array(_get_random_common_runes(2, Rune.RuneType.SUPPORT))
			#hand.append(RANDOM_SELECTION)
			hand.shuffle()

	# Drop card based on difficulty level
	var reduction := Difficulty.get_starting_hand_reduction(GameManager.selected_difficulty)
	for _i in reduction:
		if hand.is_empty():
			break
		hand.pop_back()

	return hand


# Draw producers with a guaranteed score rune among them.
static func _get_starting_producer_runes(count: int) -> Array[Rune]:
	if count <= 0:
		return []

	# Lock in one score producer first so the opening hand can always score.
	var producers: Array[Rune] = _get_random_common_runes(
		1, Rune.RuneType.PRODUCER, Rune.Product.SCORE
	)

	# Fill the remaining slots from any common producer, excluding the score pick.
	var remaining_count := count - producers.size()
	if remaining_count <= 0:
		return producers

	var used_ids: Dictionary = {}
	for rune in producers:
		used_ids[rune.id] = true

	var available_pool: Array[Rune] = []
	for rune in GameManager.runes_pool:
		if used_ids.has(rune.id):
			continue
		available_pool.append(rune)

	producers.append_array(
		RuneLoot.draw_filtered(
			remaining_count,
			available_pool,
			Rune.RuneRarity.COMMON,
			Rune.RuneType.PRODUCER
		)
	)
	return producers


# Pick random common runes of the given type from the pool.
static func _get_random_common_runes(
	count: int,
	rune_type: Rune.RuneType,
	product: Variant = null
) -> Array[Rune]:
	return RuneLoot.draw_filtered(
		count,
		GameManager.runes_pool,
		Rune.RuneRarity.COMMON,
		rune_type,
		true,
		product
	)

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
