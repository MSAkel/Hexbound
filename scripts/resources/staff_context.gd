class_name StaffContext
extends RefCounted

## One hook call for one staff slot. Payouts, rolls, and feedback go through here so
## a copied effect is credited to the slot that owns it, not the slot it was copied from.

const FLAVOUR_COLOR := Color.AQUA
const MULT_COLOR := Color.PLUM
const GOLD_COLOR := Color(1.0, 0.85, 0.2, 1.0)

## Slot that owns this call. Equals the linked station index.
var slot: int = -1
## Card seated in the slot. Differs from effect when the slot holds a copy staff member.
var owner: StaffCard = null
## Staff whose hook is running.
var effect: StaffCard = null
## Null outside a run scene, for example in a headless Day hook.
var map: HexTileMap = null
## Scratch space for this slot, cleared when the Hour ends.
var hour_state: Dictionary = {}


func is_on_station(tile: Hex) -> bool:
	if tile == null or map == null:
		return false
	return map.get_segment_index(tile.coordinates) == slot


## Every card seated on this station in fire order, including ones that cannot fire.
func station_cards(filter_type: Variant = null) -> Array[TileCard]:
	if map == null or map.query == null:
		return []
	return map.query.cards_from_hexes(
		map.query.hexes_in_segment(slot), filter_type, HexBoardQuery.SeatFilter.SEATED
	)


## True while the firing card was triggered by a staff member. Reaction staff skip these to avoid loops.
func is_staff_caused_activation() -> bool:
	return map != null and map.turn_resolver != null and map.turn_resolver.is_resolving_staff_trigger()


## Fresh generator per roll. Same seed and same play replay the same result.
func rng(tag: String) -> RandomNumberGenerator:
	var roll_index := int(hour_state.get("_rolls", 0))
	hour_state["_rolls"] = roll_index + 1
	return RunRng.create_rng("staff:r%d:s%d:slot%d:%s:%s:n%d" % [
		GameManager.current_round,
		GameManager.turn_stamp,
		slot,
		effect.id if effect != null else "none",
		tag,
		roll_index,
	])


func add_flavour(amount: int) -> void:
	if map == null or amount == 0:
		return
	map.add_turn_flavour_for_segment(slot, amount)
	_float("+%d" % amount, FLAVOUR_COLOR, TileCard.ICON_FLAVOUR)
	_flash_station()
	pulse()


func add_mult(amount: float) -> void:
	if map == null or is_zero_approx(amount):
		return
	map.add_turn_additive_mult_for_segment(slot, amount)
	_float(CountingNumber.format_additive_mult(amount), MULT_COLOR, TileCard.ICON_MULT)
	_flash_station()
	pulse()


func add_gold(amount: int) -> void:
	if amount <= 0 or not EventManager.can_gain_gold():
		return
	EconomyManager.add(amount)
	if not GameManager.skip_presentation:
		AudioManager.play_sfx(UISounds.GOLD_GAINED)
	_float("+%d" % amount, GOLD_COLOR, TileCard.ICON_GOLD)
	pulse()


## Queues extra fires that resolve before the fire order moves on. Returns how many were queued.
func queue_triggers(cards: Array[TileCard]) -> int:
	if map == null or cards.is_empty() or EventManager.are_retriggers_blocked():
		return 0
	var queued := map.turn_resolver.queue_staff_triggers(cards, slot)
	if queued > 0:
		pulse()
	return queued


## Plays this slot's activation beat. Pass the affected spot to draw a bolt to it.
func pulse(target: Hex = null) -> void:
	hour_state["_acted"] = true
	if GameManager.skip_presentation:
		return
	if map != null and target != null:
		map.play_staff_bolt(slot, target)
	EventBus.staff_effect_triggered.emit(slot)


## Brief wash over the linked row so the payout reads as belonging to that station.
func _flash_station() -> void:
	if map != null and not GameManager.skip_presentation:
		map.flash_segment_highlight(slot)


func _float(text: String, color: Color, icon: Texture2D) -> void:
	if map == null:
		return
	map.create_floating_text(map.get_staff_anchor_global(slot), text, color, icon)
