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
## A tile card pack costs the regular card price of its category plus this.
const TILE_PACK_PREMIUM := 1
## Technique pack price. Flat, whatever rarities it holds.
const TECHNIQUE_PACK_PRICE := 10

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


## Regular card price of the category plus the premium. Techniques cost one flat price.
static func price(kind: Kind) -> int:
	if kind == Kind.TECHNIQUES:
		return TECHNIQUE_PACK_PRICE
	var card_price := TileCard.MEAL_SHOP_PRICE if kind == Kind.MEALS else TileCard.SHOP_PRICE
	return card_price + TILE_PACK_PREMIUM


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


## Up to SHELF_COUNT distinct kinds for the shelf, skipping the exclude kinds (locked packs).
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
		picked.append(candidates.pop_at(rng.randi_range(0, candidates.size() - 1)))
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
	var pool := _tile_pool(kind)
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
	return not _tile_pool(kind).is_empty()


## The chef-filtered draw pool, narrowed to one card type.
static func _tile_pool(kind: Kind) -> Array[TileCard]:
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
