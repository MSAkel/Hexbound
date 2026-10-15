extends Resource
class_name ChefRegistry

# Registry for playable chef definitions loaded from resources/chefs/.

const CHEF_PATHS: Array[String] = [
	"res://resources/chefs/sous_chef.tres",
	"res://resources/chefs/sommelier.tres",
	"res://resources/chefs/gourmet_restaurant.tres",
]

## Opening hand: random Ingredients and Kitchenware drawn from cards tagged starting_hand_eligible.
const STARTING_INGREDIENT_COUNT := 3
const STARTING_KITCHENWARE_COUNT := 2

static var _definitions: Array[ChefDefinition] = []
static var _definitions_by_id: Dictionary = {}


static func _ensure_loaded() -> void:
	if not _definitions.is_empty():
		return

	for path: String in CHEF_PATHS:
		var definition := load(path) as ChefDefinition
		if definition == null:
			push_error("Failed to load chef definition: %s" % path)
			continue
		_definitions.append(definition)
		_definitions_by_id[definition.id] = definition


static func get_all_chefs() -> Array[ChefDefinition]:
	_ensure_loaded()
	return _definitions


static func get_default_chef() -> ChefDefinition:
	_ensure_loaded()
	return _definitions[0]


static func get_chef_by_id(chef_id: String) -> ChefDefinition:
	_ensure_loaded()
	return _definitions_by_id.get(chef_id)


# Build the starting hand: 3 random Ingredients and 2 random Kitchenware.
# Difficulty may trim Kitchenware first.
static func get_starting_hand_cards(chef: ChefDefinition) -> Array[TileCard]:
	var hand: Array[TileCard] = []
	if chef == null:
		return hand

	hand.append_array(_draw_starters(STARTING_INGREDIENT_COUNT, TileCard.TileCardType.INGREDIENT))
	hand.append_array(_draw_starters(STARTING_KITCHENWARE_COUNT, TileCard.TileCardType.KITCHENWARE))

	var reduction := Difficulty.get_starting_hand_reduction(GameManager.selected_difficulty)
	_apply_starting_hand_reduction(hand, reduction)
	RunRng.shuffle(hand)
	return hand


# Opening deal size before mid-run draws and plays shrink the hand.
static func get_expected_opening_hand_size(difficulty: Difficulty.Level) -> int:
	return STARTING_INGREDIENT_COUNT + STARTING_KITCHENWARE_COUNT - Difficulty.get_starting_hand_reduction(difficulty)


static func _draw_starters(count: int, card_type: TileCard.TileCardType) -> Array[TileCard]:
	var pool: Array[TileCard] = []
	for card in GameManager.tile_cards_pool:
		if card.starting_hand_eligible:
			pool.append(card)
	return CardLoot.draw_filtered(count, pool, card_type)


# Remove Kitchenware before Ingredients.
static func _apply_starting_hand_reduction(hand: Array[TileCard], reduction: int) -> void:
	for _i in mini(reduction, hand.size()):
		var index := hand.size() - 1
		for candidate in hand.size():
			if hand[candidate].type == TileCard.TileCardType.KITCHENWARE:
				index = candidate
				break
		hand.remove_at(index)
