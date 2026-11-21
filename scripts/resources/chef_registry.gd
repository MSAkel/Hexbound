extends Resource
class_name ChefRegistry

# Registry for playable chef definitions loaded from resources/chefs/. Also builds starting decks.

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

## Default deck for chefs without deck_stations: random Ingredients and Kitchenware drawn from
## cards tagged starting_hand_eligible. Untuned.
const DEFAULT_INGREDIENT_COUNT := 11
const DEFAULT_KITCHENWARE_COUNT := 4
const STATION_KIT_DIR := "res://resources/station_kits/"
const STATION_KIT_IDS: Array[String] = [
	"grilling", "cold", "fish", "pastry", "sauce", "roasting", "bar", "fry",
]

static var _definitions: Array[ChefDefinition] = []
static var _definitions_by_id: Dictionary = {}
static var _kits_by_station: Dictionary = {}


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


## Builds the chef's starting deck. Call inside a fresh RunRng stream ("starting_deck:<chef id>")
## so a seed always deals the same deck. Returns {"cards": Array[TileCard], "stations": Array[String]},
## where stations are the kit Station ids in order (home first).
static func build_starting_deck(chef: ChefDefinition) -> Dictionary:
	var cards: Array[TileCard] = []
	var stations: Array[String] = []
	if chef == null:
		return {"cards": cards, "stations": stations}
	if not chef.has_station_deck():
		cards.append_array(_draw_starters(DEFAULT_INGREDIENT_COUNT, TileCard.TileCardType.INGREDIENT))
		cards.append_array(_draw_starters(DEFAULT_KITCHENWARE_COUNT, TileCard.TileCardType.KITCHENWARE))
		return {"cards": cards, "stations": stations}

	var swaps := _parse_swaps(chef)
	var used_ids: Array[String] = []
	for entry: String in chef.deck_stations:
		var parts := entry.split(":")
		var station_id := _roll_station(parts[0], stations)
		if station_id.is_empty():
			push_error("ChefRegistry: %s deck entry '%s' found no Station kit." % [chef.id, entry])
			continue
		stations.append(station_id)
		var kit := get_station_kit(station_id)
		var size := StationKit.size_from_id(parts[1] if parts.size() > 1 else "full")
		var kit_entries := kit.entries_for(size)
		for slot in kit_entries.size():
			var card_entry: String = swaps.get("%s:%d" % [station_id, slot + 1], kit_entries[slot])
			var card := _deal_entry(card_entry, used_ids)
			if card == null:
				push_error("ChefRegistry: %s deck entry '%s' (%s slot %d) gave no card." % [chef.id, card_entry, station_id, slot + 1])
				continue
			cards.append(card)
			used_ids.append(card.id)
	return {"cards": cards, "stations": stations}


## Starting deck size, for the deal check.
static func get_expected_deck_size(chef: ChefDefinition = null) -> int:
	if chef == null or not chef.has_station_deck():
		return DEFAULT_INGREDIENT_COUNT + DEFAULT_KITCHENWARE_COUNT
	var total := 0
	for entry: String in chef.deck_stations:
		var parts := entry.split(":")
		total += int(StationKit.SIZE_COUNTS[StationKit.size_from_id(parts[1] if parts.size() > 1 else "full")])
	return total


static func get_station_kit(station_id: String) -> StationKit:
	if _kits_by_station.is_empty():
		for kit_id: String in STATION_KIT_IDS:
			var kit := load("%s%s.tres" % [STATION_KIT_DIR, kit_id]) as StationKit
			if kit == null:
				push_error("ChefRegistry: failed to load Station kit %s." % kit_id)
				continue
			_kits_by_station[kit.station_id] = kit
	return _kits_by_station.get(station_id)


static func get_station_kits() -> Array[StationKit]:
	get_station_kit("")
	var kits: Array[StationKit] = []
	for kit_id: String in STATION_KIT_IDS:
		var kit: StationKit = _kits_by_station.get("%s_station" % kit_id)
		if kit != null:
			kits.append(kit)
	return kits


## One Station id from a deck_stations choice, skipping Stations already in the deck.
static func _roll_station(choice: String, taken: Array[String]) -> String:
	var options: Array[String] = []
	if choice == ChefDefinition.ANY_STATION:
		for kit: StationKit in get_station_kits():
			options.append(kit.station_id)
	else:
		for option: String in choice.split("|"):
			options.append(option.strip_edges())
	var fresh: Array[String] = []
	for option: String in options:
		if option not in taken and get_station_kit(option) != null:
			fresh.append(option)
	if fresh.is_empty():
		return ""
	if fresh.size() == 1:
		return fresh[0]
	return fresh[RunRng.randi_range(0, fresh.size() - 1)]


static func _parse_swaps(chef: ChefDefinition) -> Dictionary:
	var swaps: Dictionary = {}
	for swap: String in chef.kit_swaps:
		var halves := swap.split("=")
		if halves.size() != 2:
			push_error("ChefRegistry: %s kit swap '%s' is not '<station>:<slot>=<card>'." % [chef.id, swap])
			continue
		swaps[halves[0].strip_edges()] = halves[1].strip_edges()
	return swaps


## A card id or a random entry, as a fresh deck card.
static func _deal_entry(entry: String, used_ids: Array[String]) -> TileCard:
	if entry.begins_with(ChefDefinition.RANDOM_PREFIX):
		var drawn := _draw_random_entry(entry.substr(ChefDefinition.RANDOM_PREFIX.length()), used_ids)
		return DeckManager.make_deck_card(drawn) if drawn != null else null
	var template := GameManager.get_tile_card_by_id(entry)
	if template == null:
		return null
	return DeckManager.make_deck_card(template)


## One random starting-hand-eligible card the chef can see. kind is "kitchenware", "ingredient"
## or an Ingredient tag. Cards already in the deck are skipped while others remain.
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
	var cards: Array[TileCard] = []
	for card: TileCard in CardLoot.draw_filtered(count, pool, card_type):
		cards.append(DeckManager.make_deck_card(card))
	return cards
