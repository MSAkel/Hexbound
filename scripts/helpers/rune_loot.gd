class_name RuneLoot
extends RefCounted

# Shared rarity-weighted rune drafting for merchant, selection packs, and future rewards.

# Chance to roll each rarity when drafting (must sum to 100).
const RARITY_WEIGHTS := {
	TileCard.TileCardRarity.COMMON: 55.0,
	TileCard.TileCardRarity.UNCOMMON: 35.0,
	TileCard.TileCardRarity.RARE: 10.0,
}
const RARITY_ROLL_ORDER: Array[TileCard.TileCardRarity] = [
	TileCard.TileCardRarity.COMMON,
	TileCard.TileCardRarity.UNCOMMON,
	TileCard.TileCardRarity.RARE,
]


# Roll one rarity using RARITY_WEIGHTS (or a custom weight table).
static func _roll_rarity(
	weights: Dictionary = RARITY_WEIGHTS,
	rng: RandomNumberGenerator = null
) -> TileCard.TileCardRarity:
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

	# Floating-point edge case: land on the last declared rarity.
	return TileCard.TileCardRarity.COMMON


# Keep runes that match optional rarity, type, and product filters.
static func _filter_runes(
	pool: Array[TileCard],
	rarity: Variant,
	rune_type: Variant,
	product: Variant = null
) -> Array[TileCard]:
	var filtered: Array[TileCard] = []
	for rune in pool:
		if rarity != null and rune.rarity != rarity:
			continue
		if rune_type != null and rune.type != rune_type:
			continue
		if product != null and rune.product != product:
			continue
		filtered.append(rune)
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


static func _pick_from(pool: Array[TileCard], rng: RandomNumberGenerator) -> TileCard:
	var sorted := _sorted_by_id(pool)
	if sorted.is_empty():
		return null
	return sorted[_randi_range(rng, 0, sorted.size() - 1)]


# Draw `count` runes with rarity weights. Each slot rolls rarity, then picks from that bucket.
# Falls back to any remaining rune when the rolled rarity has no candidates left.
# Pass rng to isolate this draft from gameplay rolls. Same rng seed always yields the same ids.
static func draw_runes(
	count: int,
	pool: Array[TileCard] = [],
	unique: bool = true,
	rng: RandomNumberGenerator = null
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available := _sorted_by_id(source_pool)
	var result: Array[TileCard] = []

	for _i in count:
		if available.is_empty():
			break

		var rarity := _roll_rarity(RARITY_WEIGHTS, rng)
		var candidates := _filter_runes(available, rarity, null)
		var picked: TileCard = (
			_pick_from(candidates, rng)
			if not candidates.is_empty()
			else _pick_from(available, rng)
		)
		if picked == null:
			break

		result.append(picked.duplicate(true))
		if unique:
			available.erase(picked)

	return result


# Draw without rarity weights, optionally filter by rarity, type, and/or product.
static func draw_filtered(
	count: int,
	pool: Array[TileCard] = [],
	rarity: Variant = null,
	rune_type: Variant = null,
	unique: bool = true,
	product: Variant = null,
	rng: RandomNumberGenerator = null
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available := _sorted_by_id(_filter_runes(source_pool, rarity, rune_type, product))
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
		var picked := _pick_from(available, rng)
		if picked != null:
			result.append(picked.duplicate(true))
	return result
