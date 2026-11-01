class_name CardLoot
extends RefCounted

## Shared drafting for the card pick, merchant, events and card effects.
## Spot cards have no rarity, so every draw is uniform. Staff still roll a rarity bucket first.

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


## Card pick and merchant draw: unique cards, weighted by station draw boosts (Fish Station level 2
## makes Seafood twice as likely). With no boost active it is the same uniform draw as card_draw.
static func station_weighted_draw(
	count: int,
	pool: Array[TileCard] = [],
	rng: RandomNumberGenerator = null
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available := _sorted_by_id(_filter_cards(source_pool, null, null))
	var weights: Array[float] = []
	var any_boost := false
	for card: TileCard in available:
		var weight := StationManager.draw_weight_for(card)
		weights.append(weight)
		if not is_equal_approx(weight, 1.0):
			any_boost = true
	if not any_boost:
		return draw_filtered(count, pool, null, null, true, rng)
	# Weighted draw without replacement: each card gets the key u^(1/weight); highest keys win.
	var keyed: Array = []
	for i in available.size():
		var u := maxf(_randf(rng), 0.000001)
		keyed.append([pow(u, 1.0 / weights[i]), i])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var result: Array[TileCard] = []
	for k in mini(count, keyed.size()):
		result.append(available[int(keyed[k][1])].duplicate(true))
	return result


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
