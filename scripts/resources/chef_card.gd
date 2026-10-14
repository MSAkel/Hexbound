class_name ChefCard
extends Card

## Run-long card seated in the chef column. Each slot is linked to one station.
## Chefs never sit on the pass. They react through the hooks below, which ChefManager calls.
## Station-bound chefs read ctx.slot as their station. Global chefs ignore it.

const BASE_PRICE_BY_RARITY := {
	Rarity.COMMON: 6,
	Rarity.UNCOMMON: 9,
	Rarity.RARE: 12,
}


func get_card_kind_label() -> String:
	return "Chef"


func get_save_kind() -> String:
	return "chef_card"


func get_base_price() -> int:
	return BASE_PRICE_BY_RARITY.get(rarity, DEFAULT_PRICE)


func get_shop_price(discount: float = 0.0) -> int:
	return _apply_merchant_discount(get_base_price(), discount)


## Half the undiscounted price, rounded down.
func get_sell_value() -> int:
	return floori(get_base_price() / 2.0)


func get_purchase_block_reason() -> String:
	if ChefManager.has_free_slot():
		return ""
	return "No free Chef slot"


#region --- Hooks ---

## Chef whose effect runs for this slot. Copy chefs return another slot's chef, or null.
func resolve_effect(_manager: Node, _slot: int, _depth: int) -> ChefCard:
	return self


## Before the first spot of this chef's station fires.
func on_station_started(_ctx: ChefContext) -> void:
	pass


## After any spot card fires. card is the occupant of tile.
func on_card_activated(_ctx: ChefContext, _tile: Hex, _card: TileCard) -> void:
	pass


## After a seated card gains a Garnish stack.
func on_card_garnished(_ctx: ChefContext, _tile: Hex, _card: TileCard) -> void:
	pass


## Extra Garnish stacks this card may hold on top of TileCard.MAX_GARNISH_STACKS.
func bonus_max_garnish_stacks(_ctx: ChefContext, _tile: Hex, _card: TileCard) -> int:
	return 0


## Extra Garnish stacks applied when a Kitchenware garnishes target.
func extra_garnish_applications(
	_ctx: ChefContext,
	_source_tile: Hex,
	_source_card: TileCard,
	_target: TileCard
) -> int:
	return 0


## Ingredient slots every Dish may leave empty.
func dish_ingredient_discount(_ctx: ChefContext) -> int:
	return 0


## First Hour of a Day, after the merchant closes.
func on_day_started(_ctx: ChefContext) -> void:
	pass


## Day goal met, before the summary and the merchant.
func on_day_ended(_ctx: ChefContext) -> void:
	pass

#endregion --- Hooks ---
