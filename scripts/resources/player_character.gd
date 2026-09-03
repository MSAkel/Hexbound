extends Resource
class_name PlayerCharacter

# Registry for playable layout definitions loaded from resources/characters/.

const CHARACTER_PATHS: Array[String] = [
	"res://resources/characters/surveyor.tres",
	"res://resources/characters/encircler.tres",
	"res://resources/characters/spiralist.tres",
	"res://resources/characters/columnist.tres",
	"res://resources/characters/converger.tres",
]

## Always included in the opening hand. Never removed by difficulty trimming.
const GUARANTEED_STARTER_IDS: Array[String] = ["tomato", "salt"]

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


# Build the starting hand cards for the given character.
# 2 locked producers, 1 random producer, and 2 support. Difficulty may trim support first.
static func get_starting_hand_runes(character: CharacterDefinition) -> Array[TileCard]:
	var hand: Array[TileCard] = []
	if character == null:
		return hand

	hand.append_array(_get_guaranteed_starter_runes())
	hand.append_array(_draw_flat_score_starter(1))
	hand.append_array(_get_random_common_runes(2, TileCard.TileCardType.KITCHENWARE))

	var reduction := Difficulty.get_starting_hand_reduction(GameManager.selected_difficulty)
	_apply_starting_hand_reduction(hand, reduction)
	RunRng.shuffle(hand)
	return hand


# Opening deal size before mid-run draws and plays shrink the hand.
static func get_expected_opening_hand_size(difficulty: Difficulty.Level) -> int:
	# Tomato, Salt, one flat producer, and two support cards.
	return 5 - Difficulty.get_starting_hand_reduction(difficulty)


# Locked opening producers that always enable a turn-1 Flavour x Mult line.
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
	for card in GameManager.tile_cards_pool:
		if card.rarity != TileCard.TileCardRarity.COMMON:
			continue
		if card.type != TileCard.TileCardType.INGREDIENT:
			continue
		if card.product != TileCard.Product.SCORE:
			continue
		if not card.starting_hand_eligible:
			continue
		if card.id in GUARANTEED_STARTER_IDS:
			continue
		if not card.is_legal_for_layout(GameManager.selected_character):
			continue
		pool.append(card)
	return pool


# Draw score producers from the flat starter pool. Falls back to any common score producer.
static func _draw_flat_score_starter(count: int) -> Array[TileCard]:
	var flat_pool := _get_flat_score_starter_pool()
	if not flat_pool.is_empty():
		return CardLoot.draw_filtered(
			count,
			flat_pool,
			TileCard.TileCardRarity.COMMON,
			TileCard.TileCardType.INGREDIENT,
			true,
			TileCard.Product.SCORE
		)

	push_warning("No flat-score starter cards tagged. Falling back to any common score producer.")
	return _get_random_common_runes(count, TileCard.TileCardType.INGREDIENT, TileCard.Product.SCORE)


# Remove support cards before optional producers. Never discard locked starters.
static func _apply_starting_hand_reduction(hand: Array[TileCard], reduction: int) -> void:
	for _i in reduction:
		if hand.is_empty():
			break

		var removed := false
		for index in hand.size():
			if hand[index].type == TileCard.TileCardType.KITCHENWARE:
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
	return CardLoot.draw_filtered(
		count,
		GameManager.tile_cards_pool,
		TileCard.TileCardRarity.COMMON,
		rune_type,
		true,
		product
	)
