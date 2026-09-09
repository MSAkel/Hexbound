extends Node

## Queryable tallies for payoff cards and end-of-run displays.
## Fires by kind/type, dishes plated, card consumes, condiment uses, Pass relays,
## and permanent growth are run-scoped.
## Only retriggers_this_hour resets each Hour. Day-scoped tallies are not stored here.
## Gold Day spend lives on GoldManager. Day rating lives on GameManager round score.

## Total card fires this run. Game-over UI reads this through GameManager.total_rune_activations.
var total_fires: int = 0
var fires_by_kind: Dictionary = {}
var fires_by_type: Dictionary = {}
var dishes_plated: int = 0
var cards_consumed: int = 0
var condiments_used: int = 0
var pass_relays: int = 0
var retriggers_this_hour: int = 0
var retriggers_this_run: int = 0
var permanent_growth_this_run: float = 0.0
## Course indexes that received at least one Pass this run.
var _relay_courses: Dictionary = {}


func _ready() -> void:
	EventBus.turn_started.connect(_on_turn_started)


func reset_for_new_run() -> void:
	total_fires = 0
	fires_by_kind.clear()
	fires_by_type.clear()
	dishes_plated = 0
	cards_consumed = 0
	condiments_used = 0
	pass_relays = 0
	retriggers_this_run = 0
	permanent_growth_this_run = 0.0
	_relay_courses.clear()
	_reset_hour_counters()


func capture_run_state() -> Dictionary:
	return {
		"total_fires": total_fires,
		"fires_by_kind": fires_by_kind.duplicate(),
		"fires_by_type": fires_by_type.duplicate(),
		"dishes_plated": dishes_plated,
		"cards_consumed": cards_consumed,
		"condiments_used": condiments_used,
		"pass_relays": pass_relays,
		"retriggers_this_hour": retriggers_this_hour,
		"retriggers_this_run": retriggers_this_run,
		"permanent_growth_this_run": permanent_growth_this_run,
		"relay_courses": _relay_courses.keys(),
	}


func apply_run_state(state: Dictionary) -> void:
	total_fires = int(state.get("total_fires", 0))
	fires_by_kind = _string_int_dict(state.get("fires_by_kind", {}))
	fires_by_type = _string_int_dict(state.get("fires_by_type", {}))
	dishes_plated = int(state.get("dishes_plated", 0))
	cards_consumed = int(state.get("cards_consumed", 0))
	condiments_used = int(state.get("condiments_used", 0))
	pass_relays = int(state.get("pass_relays", 0))
	retriggers_this_hour = int(state.get("retriggers_this_hour", 0))
	retriggers_this_run = int(state.get("retriggers_this_run", 0))
	permanent_growth_this_run = float(state.get("permanent_growth_this_run", 0.0))
	_relay_courses.clear()
	var courses: Variant = state.get("relay_courses", [])
	if courses is Array:
		for entry in courses:
			_relay_courses[int(entry)] = true


func get_fires_for_kind(tag: StringName) -> int:
	return int(fires_by_kind.get(String(tag), 0))


func get_fires_for_type(card_type: TileCard.TileCardType) -> int:
	return int(fires_by_type.get(_type_key(card_type), 0))


func get_distinct_relay_courses() -> int:
	return _relay_courses.size()


## Called from GameManager.register_tile_card_activation after this Hour's count is updated.
## is_retrigger is computed once from the Hour identity map, not scanned again here.
func record_card_fired(card: TileCard, is_retrigger: bool = false) -> void:
	if card == null:
		return
	total_fires += 1
	_bump(fires_by_type, _type_key(card.type))
	for tag: StringName in TileCard.queryable_kind_tags(card):
		_bump(fires_by_kind, String(tag))
	if is_retrigger:
		retriggers_this_hour += 1
		retriggers_this_run += 1


func record_dish_plated() -> void:
	dishes_plated += 1


func record_card_consumed(card: TileCard) -> void:
	if card == null:
		return
	cards_consumed += 1


func record_condiment_used() -> void:
	condiments_used += 1


func record_pass_relay(segment_index: int) -> void:
	pass_relays += 1
	if segment_index < 0:
		return
	_relay_courses[segment_index] = true


func record_permanent_growth(amount: float) -> void:
	if amount <= 0.0:
		return
	permanent_growth_this_run += amount


func _on_turn_started() -> void:
	_reset_hour_counters()


## Hour keys only. Add new Hour maps here when a card needs this-Hour fires, not Day or run.
func _reset_hour_counters() -> void:
	retriggers_this_hour = 0


func _bump(store: Dictionary, key: String, amount: int = 1) -> void:
	store[key] = int(store.get(key, 0)) + amount


func _type_key(card_type: TileCard.TileCardType) -> String:
	var key: Variant = TileCard.TileCardType.find_key(card_type)
	if key == null:
		return str(int(card_type))
	return String(key)


func _string_int_dict(value: Variant) -> Dictionary:
	var result := {}
	if not value is Dictionary:
		return result
	for entry_key: Variant in value.keys():
		result[String(entry_key)] = int(value[entry_key])
	return result
