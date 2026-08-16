extends Resource
class_name PlayerCharacter

# Registry for playable character definitions loaded from resources/characters/.

const CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/surveyor.tres",
	"res://resources/characters/encircler.tres",
	"res://resources/characters/spiralist.tres",
	"res://resources/characters/columnist.tres",
	"res://resources/characters/converger.tres",
	"res://resources/characters/wildcard.tres",
]

static var _definitions: Array[CharacterDefinition] = []
static var _definitions_by_id: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return

	for path: String in CHARACTER_PATHS:
		var definition := load(path) as CharacterDefinition
		if definition == null:
			push_error("Failed to load character definition: %s" % path)
			continue
		_definitions.append(definition)
		_definitions_by_id[definition.id] = definition


static func get_all_characters() -> Array[CharacterDefinition]:
	_ensure_loaded()
	return _definitions


static func get_default_character() -> CharacterDefinition:
	_ensure_loaded()
	return _definitions[0]


static func get_character_by_id(character_id: String) -> CharacterDefinition:
	_ensure_loaded()
	return _definitions_by_id.get(character_id)


# Build the starting hand runes for the given character.
# 5 random common cards: 3 production (at least one score) and 2 support.
static func get_starting_hand_runes(character: CharacterDefinition) -> Array[Rune]:
	var hand: Array[Rune] = []
	if character == null:
		return hand

	# 5 common runes, then difficulty may drop cards from the back.
	hand.append_array(_get_starting_producer_runes(3))
	hand.append_array(_get_random_common_runes(2, Rune.RuneType.SUPPORT))
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
