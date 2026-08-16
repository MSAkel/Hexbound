class_name RuneLoot
extends RefCounted

# Shared rarity-weighted rune drafting for merchant, selection packs, and future rewards.

# Chance to roll each rarity when drafting (must sum to 100).
const RARITY_WEIGHTS := {
	TileCard.TileCardRarity.COMMON: 55.0,
	TileCard.TileCardRarity.UNCOMMON: 35.0,
	TileCard.TileCardRarity.RARE: 10.0,
}

# Roll one rarity using RARITY_WEIGHTS (or a custom weight table).
static func _roll_rarity(weights: Dictionary = RARITY_WEIGHTS) -> TileCard.TileCardRarity:
	var total_weight := 0.0
	for weight in weights.values():
		total_weight += float(weight)

	var roll := randf() * total_weight
	var cumulative := 0.0
	for rarity in weights.keys():
		cumulative += float(weights[rarity])
		if roll <= cumulative:
			return rarity as TileCard.TileCardRarity

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


# Draw `count` runes with rarity weights. Each slot rolls rarity, then picks from that bucket.
# Falls back to any remaining rune when the rolled rarity has no candidates left.
static func draw_runes(
	count: int,
	pool: Array[TileCard] = [],
	unique: bool = true
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available: Array[TileCard] = source_pool.duplicate()
	var result: Array[TileCard] = []

	for _i in count:
		if available.is_empty():
			break

		var rarity := _roll_rarity()
		var candidates := _filter_runes(available, rarity, null)
		var picked: TileCard = (
			candidates.pick_random() if not candidates.is_empty() else available.pick_random()
		)

		result.append(picked)
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
	product: Variant = null
) -> Array[TileCard]:
	var source_pool := pool if not pool.is_empty() else GameManager.tile_cards_pool
	var available := _filter_runes(source_pool, rarity, rune_type, product)
	var result: Array[TileCard] = []

	if available.is_empty():
		return result

	if unique:
		available.shuffle()
		for i in mini(count, available.size()):
			result.append(available[i])
		return result

	# With replacement: each pick is independent.
	for _i in count:
		result.append(available.pick_random())
	return result
