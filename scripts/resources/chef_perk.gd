class_name ChefPerk
extends Resource

## A chef's run-long ability. Each chef's perk script extends this and overrides only the hooks it
## needs. Numbers live as @export fields on the chef's .tres so they can be tuned without code.
## Hooks are called through ChefRuntime (GameManager.chef). Perks are shared Resources, so any
## per-run progress goes in the state Dictionary the runtime passes in, never on the perk itself.
## state keys starting with "hour_" clear at the start of every Hour.


#region --- Run setup ---

## Starting gold before the difficulty reduction.
func starting_gold(base_gold: int) -> int:
	return base_gold


## False hides a card from every card pick, the auto-granted card, the merchant and random
## Ingredients made mid-run (Forager never sees Meat or Seafood).
func allows_card(_card: TileCard) -> bool:
	return true

#endregion


#region --- Triggers ---

## Multiplies a card's whole output for one trigger, like a station perk (Sommelier: Beverages x2).
func output_scale_for(_state: Dictionary, _tile: Hex, _card: TileCard) -> float:
	return 1.0


## Right after a card on the board has triggered.
func after_card_triggered(_state: Dictionary, _tile: Hex, _card: TileCard) -> void:
	pass


## Extra +Mult a served Meal pays, before Garnish and other multipliers (Pitmaster).
func meal_extra_mult(_state: Dictionary, _tile: Hex, _meal: MealCard) -> float:
	return 0.0


## A Meal was served. Called while it resolves, after the station counted the serving.
func on_meal_served(_state: Dictionary, _tile: Hex, _meal: MealCard) -> void:
	pass


## Before the first card of the Hour triggers. "hour_" state keys are already cleared.
func on_hour_started(_state: Dictionary) -> void:
	pass


## A new Day begins (Day 2 onwards), after the station perks' own Day start.
func on_day_started(_state: Dictionary) -> void:
	pass

#endregion


#region --- Stations ---

## Running total of Meals served to reach levels 2 to 6 on a station of this type.
func level_thresholds(_station_type: StationType, default_thresholds: Array[int]) -> Array[int]:
	return default_thresholds


## True when every station gets both level 3 options and both level 6 options instead of a pick.
func takes_every_station_pick() -> bool:
	return false

#endregion


#region --- Merchant ---

## Extra tile cards on the merchant shelf.
func extra_merchant_tile_slots() -> int:
	return 0


## Merchant rerolls that cost nothing at the start of each visit.
func free_merchant_rerolls() -> int:
	return 0

#endregion
