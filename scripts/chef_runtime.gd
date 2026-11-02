class_name ChefRuntime
extends RefCounted

## The chef chosen for this run, bound from GameManager.selected_chef (GameManager.chef).
## Game systems call these methods. Each one forwards to the chef's ChefPerk with this run's state,
## so callers never need to know which chef is playing. With no chef or no perk, every hook is neutral.

var _chef: ChefDefinition = null
## Per-run perk progress (counters, flags). Keys starting with "hour_" clear each Hour.
var _state: Dictionary = {}


## Bind the chef chosen for this run. Pass null to clear.
func bind(chef: ChefDefinition) -> void:
	_chef = chef
	_state = {}


func get_chef() -> ChefDefinition:
	return _chef


func get_id() -> String:
	return _chef.id if _chef != null else ""


func _perk() -> ChefPerk:
	return _chef.perk if _chef != null else null


## Per-Hour counters are cleared. The playtest bot also calls this after a what-if Hour.
func reset_turn() -> void:
	for key: Variant in _state.keys():
		if String(key).begins_with("hour_"):
			_state.erase(key)


#region --- Run setup ---

func starting_gold(base_gold: int) -> int:
	var perk := _perk()
	return perk.starting_gold(base_gold) if perk != null else base_gold


func allows_card(card: TileCard) -> bool:
	var perk := _perk()
	return perk == null or card == null or perk.allows_card(card)


## Only the cards this chef can be offered, in pool order.
func filter_pool(pool: Array[TileCard]) -> Array[TileCard]:
	var perk := _perk()
	if perk == null:
		return pool
	var allowed: Array[TileCard] = []
	for card: TileCard in pool:
		if perk.allows_card(card):
			allowed.append(card)
	return allowed

#endregion


#region --- Triggers ---

func output_scale_for(tile: Hex, card: TileCard) -> float:
	var perk := _perk()
	return perk.output_scale_for(_state, tile, card) if perk != null else 1.0


func after_card_triggered(tile: Hex, card: TileCard) -> void:
	var perk := _perk()
	if perk != null:
		perk.after_card_triggered(_state, tile, card)


func meal_extra_mult(tile: Hex, meal: MealCard) -> float:
	var perk := _perk()
	if perk == null or tile == null or tile.map == null:
		return 0.0
	return perk.meal_extra_mult(_state, tile, meal)


func on_meal_served(tile: Hex, meal: MealCard) -> void:
	var perk := _perk()
	if perk != null:
		perk.on_meal_served(_state, tile, meal)


func on_hour_started() -> void:
	reset_turn()
	var perk := _perk()
	if perk != null:
		perk.on_hour_started(_state)


func on_day_started() -> void:
	var perk := _perk()
	if perk != null:
		perk.on_day_started(_state)

#endregion


#region --- Stations ---

func level_thresholds(station_type: StationType, default_thresholds: Array[int]) -> Array[int]:
	var perk := _perk()
	if perk == null or station_type == null:
		return default_thresholds
	return perk.level_thresholds(station_type, default_thresholds)


func takes_every_station_pick() -> bool:
	var perk := _perk()
	return perk != null and perk.takes_every_station_pick()

#endregion


#region --- Merchant ---

func extra_merchant_tile_slots() -> int:
	var perk := _perk()
	return maxi(0, perk.extra_merchant_tile_slots()) if perk != null else 0


func free_merchant_rerolls() -> int:
	var perk := _perk()
	return maxi(0, perk.free_merchant_rerolls()) if perk != null else 0

#endregion
