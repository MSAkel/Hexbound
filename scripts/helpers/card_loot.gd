class_name CardLoot
extends RefCounted

## Shared drafting for the card pick, merchant, events and card effects.
## Card picks, the auto-granted card and the merchant use lane_draw (by card type, with station draw
## boosts). Card effects still draw uniformly. Staff still roll a rarity bucket first.

# Chance to roll each staff rarity (must sum to 100).
const RARITY_WEIGHTS := {
	Card.Rarity.COMMON: 55.0,
	Card.Rarity.UNCOMMON: 35.0,
	Card.Rarity.RARE: 10.0,
}
const RARITY_ROLL_ORDER: Array[Card.Rarity] = [
	Card.Rarity.COMMON,
	Card.Rarity.UNCOMMON,
	Card.Rarity.RARE,
]


## Roll one staff rarity using RARITY_WEIGHTS (or a custom weight table).
static func roll_rarity(
	weights: Dictionary = RARITY_WEIGHTS,
	rng: RandomNumberGenerator = null
) -> Card.Rarity:
	var total_weight := 0.0
	for rarity in RARITY_ROLL_ORDER:
		if weights.has(rarity):
			total_weight += float(weights[rarity])

	var roll := _randf(rng) * total_weight
	var cumulative := 0.0
	for rarity in RARITY_ROLL_ORDER:
		if not weights.has(rarity):
			continue
		cumulative += float(weights[rarity])
		if roll <= cumulative:
			return rarity

	# Floating-point edge case.
	return Card.Rarity.COMMON


## Draw `count` spot cards uniformly from pool (the whole pool when empty).
## Pass rng to isolate this draft from gameplay rolls. Same rng seed always yields the same ids.
static func card_draw(
	count: int,
	pool: Array[TileCard] = [],
	unique: bool = true,
	rng: RandomNumberGenerator = null
) -> Array[TileCard]:
	return draw_filtered(count, pool, null, null, unique, rng)


#region Draft lanes

## Card picks fill each slot from a lane: the slot first rolls a card type, then draws one card of
## that type. Ingredient odds no longer drop as Meals are added. The lane mix moves from building
## (Prep) to serving (Service) as the run goes on. All weights untuned.
enum DraftPhase { PREP, OPENING, SERVICE }

const _INGREDIENT := TileCard.TileCardType.INGREDIENT
const _KITCHENWARE := TileCard.TileCardType.KITCHENWARE
const _MEAL := TileCard.TileCardType.MEAL
const LANE_TYPE_ORDER: Array[TileCard.TileCardType] = [_INGREDIENT, _KITCHENWARE, _MEAL]

## Prep: Day 1 before any typed station. Two Ingredients, then a Meal or (less often) Kitchenware.
## The starting hand already holds Kitchenware, so early picks offer less of it than the old draw.
const PREP_LANES: Array[Dictionary] = [
	{_INGREDIENT: 1.0},
	{_INGREDIENT: 1.0},
	{_KITCHENWARE: 0.3, _MEAL: 0.7},
]
## Opening: Day 1 once a station is typed, or Day 2 before one is.
const OPENING_LANES: Array[Dictionary] = [
	{_INGREDIENT: 1.0},
	{_INGREDIENT: 0.7, _KITCHENWARE: 0.3},
	{_MEAL: 1.0},
]
## Service: everything after. Keeps 1.5 Ingredients a pick so second and third stations still form.
const SERVICE_LANES: Array[Dictionary] = [
	{_INGREDIENT: 1.0},
	{_INGREDIENT: 0.5, _KITCHENWARE: 0.5},
	{_MEAL: 1.0},
]
## The merchant's tile shelf always holds one of each type, every Day.
const MERCHANT_LANES: Array[Dictionary] = [
	{_INGREDIENT: 1.0},
	{_KITCHENWARE: 1.0},
	{_MEAL: 1.0},
]


## Day 1 starts in Prep; each later Day and the first typed station each move one phase on.
static func draft_phase(round_number: int) -> DraftPhase:
	var stage := maxi(0, round_number - 1)
	if has_typed_station():
		stage += 1
	if stage <= 0:
		return DraftPhase.PREP
	if stage == 1:
		return DraftPhase.OPENING
	return DraftPhase.SERVICE


static func lanes_for_phase(phase: DraftPhase) -> Array[Dictionary]:
	match phase:
		DraftPhase.PREP:
			return PREP_LANES
		DraftPhase.OPENING:
			return OPENING_LANES
	return SERVICE_LANES


static func lanes_for_round(round_number: int) -> Array[Dictionary]:
	return lanes_for_phase(draft_phase(round_number))


static func has_typed_station() -> bool:
	for seg in StationManager.get_station_count():
		if StationManager.get_station_type(seg) != null:
			return true
	return false


## Draw `count` unique cards, slot i from lanes[i], weighted by station draw boosts within the lane
## (Fish Station level 2 makes Seafood twice as likely among Ingredients). When count does not match
## the lane count (Dealt Hand grants one card), every slot uses the lanes' combined mix instead.
## A lane whose types are used up falls back to any type left. exclude_ids never appear.
static func lane_draw(
	lanes: Array[Dictionary],
	count: int,
	pool: Array[TileCard] = [],
	rng: RandomNumberGenerator = null,
	exclude_ids: Array[String] = []
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var by_type: Dictionary = {}
	for card_type in LANE_TYPE_ORDER:
		var of_type: Array[TileCard] = []
		for card: TileCard in _sorted_by_id(_filter_cards(source_pool, card_type, null)):
			if card.id not in exclude_ids:
				of_type.append(card)
		by_type[card_type] = of_type

	var combined := _combined_lane(lanes)
	var result: Array[TileCard] = []
	for slot in count:
		var lane: Dictionary = lanes[slot] if count == lanes.size() else combined
		var card_type: Variant = _roll_lane_type(lane, by_type, rng)
		if card_type == null:
			card_type = _roll_lane_type(combined, by_type, rng)
		if card_type == null:
			card_type = _roll_lane_type({_INGREDIENT: 1.0, _KITCHENWARE: 1.0, _MEAL: 1.0}, by_type, rng)
		if card_type == null:
			break
		var candidates: Array[TileCard] = by_type[card_type]
		var index := _weighted_index(candidates, rng)
		result.append(candidates[index].duplicate(true))
		candidates.remove_at(index)
	return result


static func _combined_lane(lanes: Array[Dictionary]) -> Dictionary:
	var combined: Dictionary = {}
	for lane: Dictionary in lanes:
		for card_type in lane:
			combined[card_type] = float(combined.get(card_type, 0.0)) + float(lane[card_type])
	return combined


## Roll a type from the lane's weights, skipping types with no cards left. Null when none are left.
static func _roll_lane_type(lane: Dictionary, by_type: Dictionary, rng: RandomNumberGenerator) -> Variant:
	var total := 0.0
	for card_type in LANE_TYPE_ORDER:
		if lane.has(card_type) and not (by_type[card_type] as Array).is_empty():
			total += float(lane[card_type])
	if total <= 0.0:
		return null
	var roll := _randf(rng) * total
	var last: Variant = null
	for card_type in LANE_TYPE_ORDER:
		if not lane.has(card_type) or (by_type[card_type] as Array).is_empty():
			continue
		last = card_type
		roll -= float(lane[card_type])
		if roll < 0.0:
			return card_type
	return last


## One card from candidates, weighted by StationManager.draw_weight_for.
static func _weighted_index(candidates: Array[TileCard], rng: RandomNumberGenerator) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for card: TileCard in candidates:
		var weight := StationManager.draw_weight_for(card)
		weights.append(weight)
		total += weight
	var roll := _randf(rng) * total
	for i in weights.size():
		roll -= weights[i]
		if roll < 0.0:
			return i
	return candidates.size() - 1

#endregion


## Uniform draw, optionally filtered by card type and/or product.
static func draw_filtered(
	count: int,
	pool: Array[TileCard] = [],
	card_type: Variant = null,
	product: Variant = null,
	unique: bool = true,
	rng: RandomNumberGenerator = null
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available := _sorted_by_id(_filter_cards(source_pool, card_type, product))
	var result: Array[TileCard] = []

	if available.is_empty():
		return result

	if unique:
		_shuffle_array(available, rng)
		for i in mini(count, available.size()):
			result.append(available[i].duplicate(true))
		return result

	# With replacement: each pick is independent.
	for _i in count:
		result.append(available[_randi_range(rng, 0, available.size() - 1)].duplicate(true))
	return result


static func _filter_cards(pool: Array[TileCard], card_type: Variant, product: Variant) -> Array[TileCard]:
	var filtered: Array[TileCard] = []
	for card in pool:
		if card_type != null and card.type != card_type:
			continue
		if product != null and card.product != product:
			continue
		filtered.append(card)
	return filtered


static func _sorted_by_id(pool: Array[TileCard]) -> Array[TileCard]:
	var sorted := pool.duplicate()
	sorted.sort_custom(func(a: TileCard, b: TileCard) -> bool:
		if a.id != b.id:
			return a.id < b.id
		return a.resource_path < b.resource_path
	)
	return sorted


static func _randf(rng: RandomNumberGenerator) -> float:
	if rng != null:
		return rng.randf()
	return RunRng.randf()


static func _randi_range(rng: RandomNumberGenerator, from_value: int, to_value: int) -> int:
	if rng != null:
		return rng.randi_range(from_value, to_value)
	return RunRng.randi_range(from_value, to_value)


static func _shuffle_array(array: Array, rng: RandomNumberGenerator) -> void:
	for index in range(array.size() - 1, 0, -1):
		var swap_index := _randi_range(rng, 0, index)
		var temp: Variant = array[index]
		array[index] = array[swap_index]
		array[swap_index] = temp
