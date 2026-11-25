class_name MerchantPacks
extends RefCounted

## Merchant packs: a shelf item that opens into four cards of one category, and the buyer keeps one.
## A pack is how a player pays to aim at a kind of card instead of rerolling for luck.
## Shelf kinds and pack contents are static draws, so the headless playtest bot shops the same packs.
## Every number in this file is untuned.

enum Kind {
	INGREDIENTS,
	KITCHENWARE,
	MEALS,
	TECHNIQUES,
}

## Packs on the shelf per visit. Never two of the same kind.
const SHELF_COUNT := 2
## Cards shown when a pack opens. The buyer keeps one.
const CARD_COUNT := 4
## Pack price per Kind (Produce Basket, Utensil Drawer, Recipe Box, Chef's Notebook). Flat, whatever
## the pack holds. Untuned.
const PRICES: Array[int] = [3, 3, 4, 4]
## How likely each Kind is for a pack slot, per Kind: Recipe Box and Chef's Notebook most. Untuned.
const KIND_WEIGHTS: Array[float] = [1.0, 1.0, 3.0, 3.0]
## How likely each Kind is for each Merchant shelf card, per Kind: Ingredient 5%, Kitchenware 5%,
## Meal 40%, Technique 50% (Merchant.draw_shelf_stock).
const SHELF_KIND_WEIGHTS: Array[float] = [0.05, 0.05, 0.40, 0.50]

const _IDS: Array[String] = ["produce_basket", "utensil_drawer", "recipe_box", "chefs_notebook"]
const _NAMES: Array[String] = ["Produce Basket", "Utensil Drawer", "Recipe Box", "Chef's Notebook"]
## Stream suffix for the bot's pre-purchase estimate, so it never sees the real contents.
const PREVIEW_STREAM_TAG := ":preview"


static func id_of(kind: Kind) -> String:
	return _IDS[kind]


## -1 when the id is unknown (an old or edited save).
static func kind_from_id(id: String) -> int:
	return _IDS.find(id)


static func display_name(kind: Kind) -> String:
	return _NAMES[kind]


## What the pack holds, as a plural noun.
static func contents_label(kind: Kind) -> String:
	match kind:
		Kind.INGREDIENTS:
			return GameTerms.INGREDIENT + "s"
		Kind.KITCHENWARE:
			return GameTerms.KITCHENWARE
		Kind.MEALS:
			return GameTerms.MEAL + "s"
	return GameTerms.TECHNIQUES


static func tooltip_text(kind: Kind) -> String:
	return "%s\nOpen to see %d %s. Keep 1." % [display_name(kind), CARD_COUNT, contents_label(kind)]


static func price(kind: Kind) -> int:
	return PRICES[kind]


## One Kind from candidates, by weights (per Kind; KIND_WEIGHTS when empty). -1 when there are none.
## A Kind missing from candidates (sold out) gives its share to the rest.
static func pick_weighted_kind(
	candidates: Array[Kind],
	rng: RandomNumberGenerator,
	weights: Array[float] = []
) -> int:
	var table := weights if not weights.is_empty() else KIND_WEIGHTS
	var total := 0.0
	for kind in candidates:
		total += table[kind]
	if candidates.is_empty() or total <= 0.0:
		return -1
	var roll := rng.randf() * total
	for kind in candidates:
		roll -= table[kind]
		if roll < 0.0:
			return kind
	return candidates[candidates.size() - 1]


## Why this pack cannot be bought right now. Empty when it can.
static func get_purchase_block_reason(kind: Kind) -> String:
	if kind == Kind.TECHNIQUES and not StaffManager.has_free_slot():
		return "No free %s slot" % GameTerms.TECHNIQUE
	return ""


#region Stock

## Kinds that can fill a pack right now. A chef's card filter can empty a category.
static func available_kinds() -> Array[Kind]:
	var kinds: Array[Kind] = []
	for kind: Kind in [Kind.INGREDIENTS, Kind.KITCHENWARE, Kind.MEALS, Kind.TECHNIQUES]:
		if _has_stock(kind):
			kinds.append(kind)
	return kinds


## Up to SHELF_COUNT distinct kinds for the shelf by KIND_WEIGHTS, skipping the exclude kinds (locked packs).
static func draw_kinds(stock_reroll_count: int, exclude: Array[int] = []) -> Array[Kind]:
	var rng := RunRng.create_rng(
		"merchant_packs:r%d:e%d" % [GameManager.current_round, stock_reroll_count]
	)
	var candidates: Array[Kind] = []
	for kind in available_kinds():
		if kind not in exclude:
			candidates.append(kind)
	var picked: Array[Kind] = []
	while picked.size() < SHELF_COUNT and not candidates.is_empty():
		var kind := pick_weighted_kind(candidates, rng) as Kind
		candidates.erase(kind)
		picked.append(kind)
	return picked


## The cards a pack opens into. Tile packs use the station draw weights like the rest of the shop.
## slot is the shelf slot, so two packs at one visit never open into the same draw.
static func draw_contents(
	kind: Kind,
	stock_reroll_count: int,
	slot: int,
	stream_tag: String = ""
) -> Array[Card]:
	var rng := RunRng.create_rng(
		"merchant_pack:r%d:e%d:s%d%s" % [GameManager.current_round, stock_reroll_count, slot, stream_tag]
	)
	var cards: Array[Card] = []
	if kind == Kind.TECHNIQUES:
		for staff in StaffCatalog.draw(CARD_COUNT, rng, StaffManager.owned_ids()):
			cards.append(staff)
		return cards
	var pool := tile_pool(kind)
	# An empty pool would fall back to the whole card pool and break the category.
	if pool.is_empty():
		return cards
	for tile_card in CardLoot.draw_filtered(CARD_COUNT, pool, null, null, true, rng):
		cards.append(tile_card)
	return cards


static func _has_stock(kind: Kind) -> bool:
	if kind == Kind.TECHNIQUES:
		var probe := StaffCatalog.draw(1, RandomNumberGenerator.new(), StaffManager.owned_ids())
		return not probe.is_empty()
	return not tile_pool(kind).is_empty()


## The chef-filtered draw pool, narrowed to one card type. Empty for Kind.TECHNIQUES.
static func tile_pool(kind: Kind) -> Array[TileCard]:
	if kind == Kind.TECHNIQUES:
		return []
	var wanted := TileCard.TileCardType.INGREDIENT
	if kind == Kind.KITCHENWARE:
		wanted = TileCard.TileCardType.KITCHENWARE
	elif kind == Kind.MEALS:
		wanted = TileCard.TileCardType.MEAL
	var pool: Array[TileCard] = []
	for tile_card in GameManager.get_draw_pool():
		if tile_card.type == wanted:
			pool.append(tile_card)
	return pool

#endregion
