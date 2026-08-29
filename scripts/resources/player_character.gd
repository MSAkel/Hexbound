extends Resource
class_name PlayerCharacter

# Registry for playable layout definitions loaded from resources/characters/.
# Wildcard stays in that folder but is not selectable. No layout-specific passives for it.

const CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/surveyor.tres",
	"res://resources/characters/encircler.tres",
	"res://resources/characters/spiralist.tres",
	"res://resources/characters/columnist.tres",
	"res://resources/characters/converger.tres",
]

## Always included in the opening hand. Never removed by difficulty trimming.
const GUARANTEED_STARTER_IDS: Array[String] = ["power_cell", "basic_mult"]

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
# 2 locked producers, 1 random producer, and 2 support. Difficulty may trim support first.
static func get_starting_hand_runes(character: CharacterDefinition) -> Array[TileCard]:
	var hand: Array[TileCard] = []
	if character == null:
		return hand

	hand.append_array(_get_guaranteed_starter_runes())
	hand.append_array(_draw_flat_score_starter(1))
	hand.append_array(_get_random_common_runes(2, TileCard.TileCardType.SUPPORT))

	var reduction := Difficulty.get_starting_hand_reduction(GameManager.selected_difficulty)
	_apply_starting_hand_reduction(hand, reduction)
	RunRng.shuffle(hand)
	return hand


# Locked opening producers that always enable a turn-1 Energy x Mult line.
static func _get_guaranteed_starter_runes() -> Array[TileCard]:
	var runes: Array[TileCard] = []
	for starter_id: String in GUARANTEED_STARTER_IDS:
		var template := GameManager.get_tile_card_by_id(starter_id)
		if template == null:
			push_error("Missing guaranteed starter tile card: %s" % starter_id)
			continue
		runes.append(template.duplicate(true))
	return runes


# Common score producers tagged for reliable turn-1 output.
static func _get_flat_score_starter_pool() -> Array[TileCard]:
	var pool: Array[TileCard] = []
	for rune in GameManager.tile_cards_pool:
		if rune.rarity != TileCard.TileCardRarity.COMMON:
			continue
		if rune.type != TileCard.TileCardType.PRODUCER:
			continue
		if rune.product != TileCard.Product.SCORE:
			continue
		if not rune.starting_hand_eligible:
			continue
		if rune.id in GUARANTEED_STARTER_IDS:
			continue
		if not rune.is_legal_for_layout(GameManager.selected_character):
			continue
		pool.append(rune)
	return pool


# Draw score producers from the flat starter pool. Falls back to any common score producer.
static func _draw_flat_score_starter(count: int) -> Array[TileCard]:
	var flat_pool := _get_flat_score_starter_pool()
	if not flat_pool.is_empty():
		return RuneLoot.draw_filtered(
			count,
			flat_pool,
			TileCard.TileCardRarity.COMMON,
			TileCard.TileCardType.PRODUCER,
			true,
			TileCard.Product.SCORE
		)

	push_warning("No flat-score starter cards tagged. Falling back to any common score producer.")
	return _get_random_common_runes(count, TileCard.TileCardType.PRODUCER, TileCard.Product.SCORE)


# Remove support cards before optional producers. Never discard locked starters.
static func _apply_starting_hand_reduction(hand: Array[TileCard], reduction: int) -> void:
	for _i in reduction:
		if hand.is_empty():
			break

		var removed := false
		for index in hand.size():
			if hand[index].type == TileCard.TileCardType.SUPPORT:
				hand.remove_at(index)
				removed = true
				break
		if removed:
			continue

		for index in hand.size():
			if hand[index].id in GUARANTEED_STARTER_IDS:
				continue
			hand.remove_at(index)
			removed = true
			break
		if not removed:
			break


# Pick random common runes of the given type from the pool.
static func _get_random_common_runes(
	count: int,
	rune_type: TileCard.TileCardType,
	product: Variant = null
) -> Array[TileCard]:
	return RuneLoot.draw_filtered(
		count,
		GameManager.tile_cards_pool,
		TileCard.TileCardRarity.COMMON,
		rune_type,
		true,
		product
	)
