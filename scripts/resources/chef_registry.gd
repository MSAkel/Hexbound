extends Resource
class_name ChefRegistry

# Registry for playable chef definitions loaded from resources/chefs/. Also deals starting hands.

const CHEF_PATHS: Array[String] = [
	"res://resources/chefs/sous_chef.tres",
	"res://resources/chefs/sommelier.tres",
	"res://resources/chefs/forager.tres",
	"res://resources/chefs/fishmonger.tres",
	"res://resources/chefs/pitmaster.tres",
	"res://resources/chefs/pastry_chef.tres",
	"res://resources/chefs/restaurateur.tres",
	"res://resources/chefs/chef_de_cuisine.tres",
]

## Default opening hand for chefs without a fixed one: random Ingredients and Kitchenware drawn
## from cards tagged starting_hand_eligible.
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


## Deal the chef's opening hand: its fixed starting_hand, or the default random hand.
static func get_starting_hand_cards(chef: ChefDefinition) -> Array[TileCard]:
	var hand: Array[TileCard] = []
	if chef == null:
		return hand

	if chef.has_fixed_starting_hand():
		hand = _deal_fixed_hand(chef)
	else:
		hand.append_array(_draw_starters(STARTING_INGREDIENT_COUNT, TileCard.TileCardType.INGREDIENT))
		hand.append_array(_draw_starters(STARTING_KITCHENWARE_COUNT, TileCard.TileCardType.KITCHENWARE))

	# Fixed hands keep their order so the setup reads left to right. Random hands are shuffled.
	if not chef.has_fixed_starting_hand():
		RunRng.shuffle(hand)
	return hand


## Opening deal size before mid-run draws and plays shrink the hand.
static func get_expected_opening_hand_size(chef: ChefDefinition = null) -> int:
	var size := STARTING_INGREDIENT_COUNT + STARTING_KITCHENWARE_COUNT
	if chef != null and chef.has_fixed_starting_hand():
		size = chef.starting_hand.size()
	return size


static func _deal_fixed_hand(chef: ChefDefinition) -> Array[TileCard]:
	var hand: Array[TileCard] = []
	var used_ids: Array[String] = []
	for entry: String in chef.starting_hand:
		var card: TileCard = null
		if entry.begins_with(ChefDefinition.RANDOM_PREFIX):
			card = _draw_random_entry(entry.substr(ChefDefinition.RANDOM_PREFIX.length()), used_ids)
		else:
			var template := GameManager.get_tile_card_by_id(entry)
			if template != null:
				card = template.duplicate(true) as TileCard
		if card == null:
			push_error("ChefRegistry: %s starting hand entry '%s' gave no card." % [chef.id, entry])
			continue
		hand.append(card)
		used_ids.append(card.id)
	return hand


## One random starting-hand-eligible card the chef can see. kind is "kitchenware", "ingredient"
## or an Ingredient tag. Cards already in the hand are skipped while others remain.
static func _draw_random_entry(kind: String, used_ids: Array[String]) -> TileCard:
	var card_type := TileCard.TileCardType.INGREDIENT
	if StringName(kind) == TileCard.TAG_KITCHENWARE:
		card_type = TileCard.TileCardType.KITCHENWARE
	var pool: Array[TileCard] = []
	for card: TileCard in GameManager.get_draw_pool():
		if not card.starting_hand_eligible or card.type != card_type:
			continue
		if card_type == TileCard.TileCardType.INGREDIENT and kind != ChefDefinition.RANDOM_INGREDIENT:
			if not card.has_ingredient_tag(StringName(kind)):
				continue
		pool.append(card)
	if pool.is_empty():
		return null
	var fresh: Array[TileCard] = []
	for card: TileCard in pool:
		if card.id not in used_ids:
			fresh.append(card)
	var drawn := CardLoot.draw_filtered(1, fresh if not fresh.is_empty() else pool, card_type)
	return drawn[0] if not drawn.is_empty() else null


static func _draw_starters(count: int, card_type: TileCard.TileCardType) -> Array[TileCard]:
	var pool: Array[TileCard] = []
	for card in GameManager.get_draw_pool():
		if card.starting_hand_eligible:
			pool.append(card)
	return CardLoot.draw_filtered(count, pool, card_type)
