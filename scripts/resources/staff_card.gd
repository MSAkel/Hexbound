class_name StaffCard
extends Card

## Run-long card seated in the staff column. Each slot is linked to one station.
## Staff never sit on the pass. They react through the hooks below, which StaffManager calls.
## Station-bound staff read ctx.slot as their station. Global staff ignore it.

const BASE_PRICE_BY_RARITY := {
	Rarity.COMMON: 6,
	Rarity.UNCOMMON: 9,
	Rarity.RARE: 12,
}

## Run-long counters for staff that grow. Saved with the slot. Not exported, so a fresh seat starts empty.
var run_state: Dictionary = {}


func get_card_kind_label() -> String:
	return GameTerms.TECHNIQUE


func get_save_kind() -> String:
	return "staff_card"


## Scaling staff append their current total to the authored description.
func get_description_text() -> String:
	var progress := get_progress_text()
	if progress.is_empty():
		return description
	return "%s (Currently %s)" % [description, progress]


## Current total for staff that grow over the run. Empty for staff that do not.
func get_progress_text() -> String:
	return ""


## Run-long counter added by StaffContext.grow.
func run_total(key: String) -> float:
	return float(run_state.get(key, 0.0))


## "+1" for whole totals, "+1.5" otherwise.
static func format_total(value: float) -> String:
	if is_equal_approx(value, roundf(value)):
		return "+%d" % roundi(value)
	return "+%.1f" % value


func get_base_price() -> int:
	return BASE_PRICE_BY_RARITY.get(rarity, DEFAULT_PRICE)


func get_shop_price(discount: float = 0.0) -> int:
	return _apply_merchant_discount(get_base_price(), discount)


## Half the undiscounted price, rounded down.
func get_sell_value() -> int:
	return floori(get_base_price() / 2.0)


func get_purchase_block_reason() -> String:
	if StaffManager.has_free_slot():
		return ""
	return "No free %s slot" % GameTerms.TECHNIQUE


#region --- Hooks ---

## Staff whose effect runs for this slot. Copy staff return another slot's staff, or null.
func resolve_effect(_manager: Node, _slot: int, _depth: int) -> StaffCard:
	return self


## Before the first spot of this staff member's station fires.
func on_station_started(_ctx: StaffContext) -> void:
	pass


## After the last spot of this staff member's station fires, queued retriggers included.
func on_station_finished(_ctx: StaffContext) -> void:
	pass


## After any spot card fires. card is the occupant of tile.
func on_card_activated(_ctx: StaffContext, _tile: Hex, _card: TileCard) -> void:
	pass


## After a seated card gains a Garnish stack.
func on_card_garnished(_ctx: StaffContext, _tile: Hex, _card: TileCard) -> void:
	pass


## Extra Garnish stacks this card may hold on top of TileCard.MAX_GARNISH_STACKS.
func bonus_max_garnish_stacks(_ctx: StaffContext, _tile: Hex, _card: TileCard) -> int:
	return 0


## Extra Garnish stacks applied when a Kitchenware garnishes target.
func extra_garnish_applications(
	_ctx: StaffContext,
	_source_tile: Hex,
	_source_card: TileCard,
	_target: TileCard
) -> int:
	return 0


## Garnish stacks this card keeps when the Hour ends instead of clearing.
func garnish_kept_after_hour(_ctx: StaffContext, _tile: Hex, _card: TileCard) -> int:
	return 0


## A seated card is about to be destroyed. tile is still its spot.
func on_card_destroyed(_ctx: StaffContext, _tile: Hex, _card: TileCard) -> void:
	pass


## A Meal was just served. tile is its spot.
func on_meal_served(_ctx: StaffContext, _tile: Hex, _meal: TileCard) -> void:
	pass


## A Condiment was just taken off the belt and used.
func on_condiment_used(_ctx: StaffContext, _condiment: Condiment) -> void:
	pass


## Gold just left the wallet, at the merchant or on a reroll.
func on_gold_spent(_ctx: StaffContext, _amount: int) -> void:
	pass


## Ingredient slots every Dish may leave empty.
func dish_ingredient_discount(_ctx: StaffContext) -> int:
	return 0


## First Hour of a Day, after the merchant closes.
func on_day_started(_ctx: StaffContext) -> void:
	pass


## Day goal met, before the summary and the merchant.
func on_day_ended(_ctx: StaffContext) -> void:
	pass

#endregion --- Hooks ---
