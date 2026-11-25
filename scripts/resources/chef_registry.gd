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

## Meals in every starting deck (user, Nov 24: raised from the 3 most kits gave, since Meals were
## too hard to get without the end-of-Day card pick). Untuned.
const STARTING_MEAL_COUNT := 4
## Of those, how many come from the chef's speciality (the home Station's kit, kit order). The rest
## are random Meals from the chef's pool. A chef whose home Station is rolled ("any" or "a|b"), such
## as Restaurateur and Chef de Cuisine, has no speciality and gets all random (user, Nov 24).
const SPECIALITY_MEAL_COUNT := 2

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


## Builds the chef's starting deck: one copy of every Ingredient and Kitchenware the chef can see
## (GameManager.get_draw_pool, sorted by id), plus STARTING_MEAL_COUNT different Meals:
## SPECIALITY_MEAL_COUNT from the home Station's kit and the rest random (see _starting_meal_ids). Kits no longer deal their Ingredients, Kitchenware or random entries: those are all
## in the deck already. More copies come from the Merchant. Untuned.
## Call inside a fresh RunRng stream ("starting_deck:<chef id>") so a seed always deals the same
## deck (an "any" or "a|b" Station choice rolls). Returns {"cards": Array[TileCard],
## "stations": Array[String]}, where stations are the kit Station ids in order (home first).
static func build_starting_deck(chef: ChefDefinition) -> Dictionary:
	var cards: Array[TileCard] = []
	var stations: Array[String] = []
	if chef == null:
		return {"cards": cards, "stations": stations}
	if chef.has_station_deck():
		for meal_id: String in _starting_meal_ids(chef, stations):
			cards.append(DeckManager.make_deck_card(GameManager.get_tile_card_by_id(meal_id)))
	for template: TileCard in _full_set_templates():
		cards.append(DeckManager.make_deck_card(template))
	return {"cards": cards, "stations": stations}


## Starting deck size for the deal check. stations are the kit Station ids the deck was built
## from (rolled choices differ by seed, and so does their Meal count).
static func get_expected_deck_size(chef: ChefDefinition, _stations: Array[String]) -> int:
	var total := _full_set_templates().size()
	if chef == null or not chef.has_station_deck():
		return total
	return total + mini(STARTING_MEAL_COUNT, _meal_pool_ids().size())


## Every Ingredient and Kitchenware the chef can see, one each, sorted by id so a seed deals the same.
static func _full_set_templates() -> Array[TileCard]:
	var templates: Array[TileCard] = []
	for card: TileCard in GameManager.get_draw_pool():
		if card.type == TileCard.TileCardType.INGREDIENT or card.type == TileCard.TileCardType.KITCHENWARE:
			templates.append(card)
	templates.sort_custom(func(x: TileCard, y: TileCard) -> bool: return x.id < y.id)
	return templates


## STARTING_MEAL_COUNT different Meal ids: SPECIALITY_MEAL_COUNT from the home Station's kit (kit
## order, kit_swaps applied) when the chef has a fixed home Station, then random Meals from the pool.
## Still rolls every deck_stations entry, so stations lists the kit Stations as before.
static func _starting_meal_ids(chef: ChefDefinition, stations: Array[String]) -> Array[String]:
	var pool := _meal_pool_ids()
	var picked: Array[String] = []
	_kit_meal_ids(chef, stations)
	if _has_meal_speciality(chef) and not stations.is_empty():
		var home := stations[0]
		for meal_id: String in _meal_entries("%s:full" % home, home, _parse_swaps(chef)):
			if picked.size() >= mini(SPECIALITY_MEAL_COUNT, STARTING_MEAL_COUNT):
				break
			if meal_id in pool and meal_id not in picked:
				picked.append(meal_id)
	var rest: Array[String] = []
	for meal_id: String in pool:
		if meal_id not in picked:
			rest.append(meal_id)
	while picked.size() < STARTING_MEAL_COUNT and not rest.is_empty():
		picked.append(rest.pop_at(RunRng.randi_range(0, rest.size() - 1)))
	return picked


## True when the chef's home Station (first deck_stations entry) is one fixed Station, not a roll.
static func _has_meal_speciality(chef: ChefDefinition) -> bool:
	if chef == null or chef.deck_stations.is_empty():
		return false
	var choice := chef.deck_stations[0].split(":")[0].strip_edges()
	return choice != ChefDefinition.ANY_STATION and not choice.contains("|")


## Meal ids the chef can see (GameManager.get_draw_pool), sorted so a seed rolls the same.
static func _meal_pool_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: TileCard in GameManager.get_draw_pool():
		if card.type == TileCard.TileCardType.MEAL and card.id not in ids:
			ids.append(card.id)
	ids.sort()
	return ids


## Rolls each deck_stations entry to a Station (appending it to stations) and returns the Meal ids
## its kit slots name, in kit order.
static func _kit_meal_ids(chef: ChefDefinition, stations: Array[String]) -> Array[String]:
	var swaps := _parse_swaps(chef)
	var meal_ids: Array[String] = []
	for entry: String in chef.deck_stations:
		var station_id := _roll_station(entry.split(":")[0], stations)
		if station_id.is_empty():
			push_error("ChefRegistry: %s deck entry '%s' found no Station kit." % [chef.id, entry])
			continue
		stations.append(station_id)
		meal_ids.append_array(_meal_entries(entry, station_id, swaps))
	return meal_ids


## The Meal ids one deck_stations entry deals from station_id's kit at the entry's size.
static func _meal_entries(entry: String, station_id: String, swaps: Dictionary) -> Array[String]:
	var meal_ids: Array[String] = []
	var kit := get_station_kit(station_id)
	if kit == null:
		return meal_ids
	var parts := entry.split(":")
	var size := StationKit.size_from_id(parts[1] if parts.size() > 1 else "full")
	var kit_entries := kit.entries_for(size)
	for slot in kit_entries.size():
		var card_entry: String = swaps.get("%s:%d" % [station_id, slot + 1], kit_entries[slot])
		if card_entry.begins_with(ChefDefinition.RANDOM_PREFIX):
			continue
		var template := GameManager.get_tile_card_by_id(card_entry)
		if template != null and template.type == TileCard.TileCardType.MEAL:
			meal_ids.append(card_entry)
	return meal_ids


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
