class_name SegmentPassiveRuntime
extends RefCounted

## Applies placed segment passives during a run. Card-facing only. No segment score patches.

var _passives_by_segment: Dictionary = {}
var _first_producer_fired: Dictionary = {}
var _first_support_fired: Dictionary = {}
var _relay_charges: Dictionary = {}
var _relay_empower_armed: Dictionary = {}
var _last_numeric_product: Dictionary = {}
var _last_card_type: Dictionary = {}
var _products_this_turn: Dictionary = {}
var _one_tile_ward_used: Dictionary = {}
var _end_retrigger_used: Dictionary = {}
var _closed_orbit_used: Dictionary = {}
var _outward_pulse_used: Dictionary = {}
var _turnaround_used: Dictionary = {}
var _singularity_used: Dictionary = {}
var _singularity_break_armed: Dictionary = {}
var _pending_turnaround_empower: Dictionary = {}
var _counted_full_segment: bool = false
var _counted_resonant_fill: bool = false


func bind(passives_by_segment: Dictionary) -> void:
	_passives_by_segment = passives_by_segment.duplicate()


func reset_turn() -> void:
	_first_producer_fired.clear()
	_first_support_fired.clear()
	_relay_charges.clear()
	_relay_empower_armed.clear()
	_last_numeric_product.clear()
	_last_card_type.clear()
	_products_this_turn.clear()
	_one_tile_ward_used.clear()
	_end_retrigger_used.clear()
	_closed_orbit_used.clear()
	_outward_pulse_used.clear()
	_turnaround_used.clear()
	_singularity_used.clear()
	_singularity_break_armed.clear()
	_pending_turnaround_empower.clear()
	_counted_full_segment = false
	_counted_resonant_fill = false


func get_passives(segment_index: int) -> Array[SegmentPassive]:
	var raw: Variant = _passives_by_segment.get(segment_index, [])
	var result: Array[SegmentPassive] = []
	if raw is Array:
		for entry in raw:
			if entry is SegmentPassive:
				result.append(entry)
	return result


func has_effect(segment_index: int, effect_type: SegmentPassive.EffectType) -> bool:
	for passive in get_passives(segment_index):
		if passive.effect_type == effect_type:
			return true
	return false


func count_effect(segment_index: int, effect_type: SegmentPassive.EffectType) -> int:
	var count := 0
	for passive in get_passives(segment_index):
		if passive.effect_type == effect_type:
			count += 1
	return count


## Empower and relay setup that must happen before this activation's empower consume.
func before_activation(tile: Hex, card: TileCard) -> void:
	if tile == null or tile.map == null or card == null:
		return
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	if segment_index < 0:
		return

	_apply_singularity_before(tile, card, segment_index)
	_apply_first_producer_empower(tile, card, segment_index)
	_apply_last_producer_empower(tile, card, segment_index)
	_apply_relay_empower(tile, card, segment_index)
	_apply_outward_pulse(tile, card, segment_index)
	_apply_pending_turnaround(card, segment_index)


func get_output_scale_bonus(tile: Hex, card: TileCard) -> float:
	if tile == null or tile.map == null or card == null:
		return 1.0
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	if segment_index < 0:
		return 1.0

	var bonus := 0.0
	var is_one_tile := tile.map.get_segment_size(segment_index) == 1
	var is_first_producer := _is_first_producer(segment_index, card)
	var is_last_producer := _is_last_producer(tile, card, segment_index)
	# Relay copies spend charges one Producer at a time. Do not stack % on one hit.
	var relay_applied := false

	for passive in get_passives(segment_index):
		match passive.effect_type:
			SegmentPassive.EffectType.ENERGY_OUTPUT_MULT:
				if card.product == TileCard.Product.SCORE:
					bonus += passive.effect_value
			SegmentPassive.EffectType.FIRST_PRODUCER_OUTPUT_MULT:
				if is_first_producer:
					bonus += passive.effect_value
			SegmentPassive.EffectType.LAST_PRODUCER_OUTPUT_MULT:
				if is_last_producer:
					bonus += passive.effect_value
			SegmentPassive.EffectType.ALTERNATING_OUTPUT_MULT:
				bonus += _alternating_bonus(segment_index, card, passive.effect_value)
			SegmentPassive.EffectType.RELAY_OUTPUT_MULT:
				if not relay_applied and card.type == TileCard.TileCardType.PRODUCER:
					var charges := int(_relay_charges.get(segment_index, 0))
					if charges > 0:
						bonus += passive.effect_value
						relay_applied = true
			SegmentPassive.EffectType.ADJACENCY_OUTPUT_MULT:
				bonus += _adjacency_bonus(tile, card, passive)
			SegmentPassive.EffectType.FULL_OCCUPANCY_OUTPUT_MULT:
				if card.type == TileCard.TileCardType.PRODUCER and _is_segment_fully_occupied(tile, segment_index):
					bonus += passive.effect_value
			SegmentPassive.EffectType.ONE_TILE_OUTPUT_MULT:
				if is_one_tile and _is_numeric_producer(card):
					bonus += passive.effect_value
			SegmentPassive.EffectType.LAYOUT_SIGHTLINE:
				if card.type == TileCard.TileCardType.PRODUCER:
					bonus += _capped_bonus(
						passive.effect_value * float(_earlier_occupied_count(tile, segment_index)),
						passive.extra_float
					)
			SegmentPassive.EffectType.LAYOUT_INWARD_MOMENTUM:
				if is_first_producer:
					bonus += _capped_bonus(
						passive.effect_value * float(_occupied_count_in_segment(tile, segment_index - 1)),
						passive.extra_float
					)
			SegmentPassive.EffectType.LAYOUT_COIL_CHARGE:
				if card.type == TileCard.TileCardType.PRODUCER:
					var earlier := maxi(0, GameManager.get_current_turn_trigger_count() - 1)
					bonus += _capped_bonus(passive.effect_value * float(earlier), passive.extra_float)
			SegmentPassive.EffectType.LAYOUT_DOWNSTROKE:
				if card.type == TileCard.TileCardType.PRODUCER:
					bonus += _capped_bonus(
						passive.effect_value * float(_consecutive_occupied_before(tile, segment_index)),
						passive.extra_float
					)
			SegmentPassive.EffectType.LAYOUT_COMPRESSION:
				if card.type == TileCard.TileCardType.PRODUCER:
					bonus += _capped_bonus(
						passive.effect_value * float(segment_index),
						passive.extra_float
					)

	bonus += card.personal_output_bonus
	return 1.0 + bonus


func after_activation(tile: Hex, card: TileCard) -> void:
	if tile == null or tile.map == null or card == null:
		return
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	if segment_index < 0:
		return

	if card.type == TileCard.TileCardType.PRODUCER:
		var previous_type: Variant = _last_card_type.get(segment_index, -1)
		if previous_type == TileCard.TileCardType.SUPPORT:
			MetaProgressionManager.add_support_then_producer()
	_last_card_type[segment_index] = card.type
	_note_numeric_product(segment_index, card)
	_apply_growth(tile, card, segment_index)
	_apply_one_tile_personal_growth(tile, card, segment_index)
	_consume_relay_charge(segment_index, card)
	_arm_relay_from_support(segment_index, card)
	_arm_turnaround(tile, card, segment_index)
	_apply_closed_orbit(tile, card, segment_index)
	# Singularity only ignores break during its own activation, not the rest of the turn.
	if bool(_singularity_break_armed.get(card, false)):
		_singularity_break_armed.erase(card)
	if _qualifies_adjacency_trigger(tile, card):
		MetaProgressionManager.add_adjacent_same_product_trigger()
	if _is_first_producer(segment_index, card):
		_first_producer_fired[segment_index] = true
	if card.type == TileCard.TileCardType.SUPPORT:
		_first_support_fired[segment_index] = true
	if _is_last_producer(tile, card, segment_index):
		MetaProgressionManager.add_last_producer_trigger()
	if not _counted_full_segment and _is_segment_fully_occupied(tile, segment_index):
		_counted_full_segment = true
		MetaProgressionManager.add_full_segment_turn()
	if not _counted_resonant_fill and _qualifies_resonant_array(tile, segment_index):
		_counted_resonant_fill = true
		MetaProgressionManager.note_resonant_array_fill()


func extra_gold_for_card(tile: Hex, card: TileCard) -> int:
	if tile == null or tile.map == null or card == null:
		return 0
	if card.product != TileCard.Product.GOLD:
		return 0
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var extra := 0
	var rng := RunRng.create_card_effect_rng(tile, card, "gold_passive")
	for passive in get_passives(segment_index):
		match passive.effect_type:
			SegmentPassive.EffectType.GOLD_FLAT_BONUS:
				extra += maxi(1, int(passive.extra_int)) if passive.extra_int > 0 else 1
			SegmentPassive.EffectType.GOLD_CHANCE_BONUS:
				if rng.randf() < passive.effect_value:
					extra += maxi(1, int(passive.extra_int)) if passive.extra_int > 0 else 1
	return extra


func should_retrigger(tile: Hex, card: TileCard) -> bool:
	if tile == null or tile.map == null or card == null:
		return false
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var rng := RunRng.create_card_effect_rng(tile, card, "passive_retrigger")
	var is_one_tile := tile.map.get_segment_size(segment_index) == 1

	for passive in get_passives(segment_index):
		match passive.effect_type:
			SegmentPassive.EffectType.SUPPORT_RETRIGGER:
				if card.type == TileCard.TileCardType.SUPPORT and rng.randf() < passive.effect_value:
					return true
			SegmentPassive.EffectType.PRODUCER_RETRIGGER:
				if card.type == TileCard.TileCardType.PRODUCER and rng.randf() < passive.effect_value:
					return true
			SegmentPassive.EffectType.ONE_TILE_RETRIGGER:
				if is_one_tile and rng.randf() < passive.effect_value:
					return true
			SegmentPassive.EffectType.LAYOUT_END_RETRIGGER:
				if _should_end_retrigger(tile, card, segment_index):
					_end_retrigger_used[segment_index] = true
					return true
			SegmentPassive.EffectType.LAYOUT_SINGULARITY:
				if tile.map.get_segment_size(segment_index) == 1 and not bool(_singularity_used.get(segment_index, false)):
					_singularity_used[segment_index] = true
					return true
	return false


func try_prevent_break(tile: Hex, card: TileCard) -> bool:
	if tile == null or tile.map == null or card == null:
		return false
	var segment_index := tile.map.get_segment_index(tile.coordinates)
	var is_one_tile := tile.map.get_segment_size(segment_index) == 1
	var rng := RunRng.create_card_effect_rng(tile, card, "break_save")

	if bool(_singularity_break_armed.get(card, false)):
		_singularity_break_armed.erase(card)
		return true

	for passive in get_passives(segment_index):
		match passive.effect_type:
			SegmentPassive.EffectType.ONE_TILE_BREAK_WARD:
				if is_one_tile and not bool(_one_tile_ward_used.get(card, false)):
					_one_tile_ward_used[card] = true
					return true
			SegmentPassive.EffectType.BREAK_SAVE_CHANCE:
				if rng.randf() < passive.effect_value:
					# Aegis Matrix unlocks from Safety Fuse saves only.
					if passive.id == "safety_fuse":
						MetaProgressionManager.add_break_prevented_by_fuse()
					return true
	return false


func on_turn_resolved(tile_map: HexTileMap) -> void:
	if tile_map == null:
		return
	for segment_index in tile_map.get_segment_count():
		var products: Variant = _products_this_turn.get(segment_index, [])
		if products is Array and products.has(TileCard.Product.SCORE) and products.has(TileCard.Product.MULTIPLIER) and products.has(TileCard.Product.GOLD):
			MetaProgressionManager.add_spectrum_turn()


func _apply_singularity_before(tile: Hex, card: TileCard, segment_index: int) -> void:
	if tile.map.get_segment_size(segment_index) != 1:
		return
	if not has_effect(segment_index, SegmentPassive.EffectType.LAYOUT_SINGULARITY):
		return
	if not card.is_empowered:
		card._empower()
	_singularity_break_armed[card] = true


func _apply_first_producer_empower(tile: Hex, card: TileCard, segment_index: int) -> void:
	if not _is_first_producer(segment_index, card):
		return
	if not has_effect(segment_index, SegmentPassive.EffectType.FIRST_PRODUCER_EMPOWER):
		return
	if not card.is_empowered:
		card._empower()


func _apply_last_producer_empower(tile: Hex, card: TileCard, segment_index: int) -> void:
	if not _is_last_producer(tile, card, segment_index):
		return
	if not has_effect(segment_index, SegmentPassive.EffectType.LAST_PRODUCER_EMPOWER):
		return
	if not card.is_empowered:
		card._empower()


func _apply_relay_empower(tile: Hex, card: TileCard, segment_index: int) -> void:
	if card.type != TileCard.TileCardType.PRODUCER:
		return
	if not bool(_relay_empower_armed.get(segment_index, false)):
		return
	_relay_empower_armed[segment_index] = false
	if not card.is_empowered:
		card._empower()


func _apply_outward_pulse(tile: Hex, card: TileCard, segment_index: int) -> void:
	if not has_effect(segment_index, SegmentPassive.EffectType.LAYOUT_OUTWARD_PULSE):
		return
	if not _is_first_producer(segment_index, card):
		return
	if segment_index <= 0:
		return
	if bool(_outward_pulse_used.get(segment_index, false)):
		return
	_outward_pulse_used[segment_index] = true
	if not card.is_empowered:
		card._empower()


func _apply_pending_turnaround(card: TileCard, segment_index: int) -> void:
	if card.type != TileCard.TileCardType.PRODUCER:
		return
	if not bool(_pending_turnaround_empower.get(segment_index, false)):
		return
	_pending_turnaround_empower.erase(segment_index)
	if not card.is_empowered:
		card._empower()


func _apply_growth(tile: Hex, card: TileCard, segment_index: int) -> void:
	var cadence_energy := 0
	var energy_gain := 0.0
	var cadence_mult := 0
	var mult_gain := 0.0
	for passive in get_passives(segment_index):
		if passive.effect_type == SegmentPassive.EffectType.ENERGY_GROWTH:
			cadence_energy = maxi(cadence_energy, maxi(1, passive.extra_int))
			energy_gain += passive.effect_value
		elif passive.effect_type == SegmentPassive.EffectType.MULT_GROWTH:
			cadence_mult = maxi(cadence_mult, maxi(1, passive.extra_int))
			mult_gain += passive.effect_value

	if card.product == TileCard.Product.SCORE and cadence_energy > 0 and energy_gain > 0.0:
		if card.run_trigger_count % cadence_energy == 0:
			card.bonus_production_amount += energy_gain
			_refresh_card_visual(tile, card)
			MetaProgressionManager.note_energy_bonus(card.bonus_production_amount)
	if card.product == TileCard.Product.MULTIPLIER and cadence_mult > 0 and mult_gain > 0.0:
		if card.run_trigger_count % cadence_mult == 0:
			card.bonus_production_amount += mult_gain
			_refresh_card_visual(tile, card)
			MetaProgressionManager.note_mult_bonus(card.bonus_production_amount)


func _apply_one_tile_personal_growth(tile: Hex, card: TileCard, segment_index: int) -> void:
	if tile.map.get_segment_size(segment_index) != 1:
		return
	for passive in get_passives(segment_index):
		if passive.effect_type != SegmentPassive.EffectType.ONE_TILE_PERSONAL_GROWTH:
			continue
		var cadence := maxi(1, passive.extra_int)
		if card.run_trigger_count % cadence != 0:
			continue
		var cap := passive.extra_float if passive.extra_float > 0.0 else 0.30
		card.personal_output_bonus = minf(cap, card.personal_output_bonus + passive.effect_value)


func _consume_relay_charge(segment_index: int, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.PRODUCER:
		return
	var charges := int(_relay_charges.get(segment_index, 0))
	if charges > 0:
		_relay_charges[segment_index] = charges - 1


func _arm_relay_from_support(segment_index: int, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.SUPPORT:
		return
	var relay_copies := count_effect(segment_index, SegmentPassive.EffectType.RELAY_OUTPUT_MULT)
	if relay_copies > 0:
		_relay_charges[segment_index] = relay_copies
	if has_effect(segment_index, SegmentPassive.EffectType.RELAY_EMPOWER):
		if not bool(_first_support_fired.get(segment_index, false)):
			_relay_empower_armed[segment_index] = true


func _arm_turnaround(tile: Hex, card: TileCard, segment_index: int) -> void:
	if not has_effect(segment_index, SegmentPassive.EffectType.LAYOUT_TURNAROUND):
		return
	if bool(_turnaround_used.get(segment_index, false)):
		return
	if not _is_last_occupied(tile, segment_index):
		return
	_turnaround_used[segment_index] = true
	_pending_turnaround_empower[segment_index + 1] = true


func _apply_closed_orbit(tile: Hex, card: TileCard, segment_index: int) -> void:
	if not has_effect(segment_index, SegmentPassive.EffectType.LAYOUT_CLOSED_ORBIT):
		return
	if bool(_closed_orbit_used.get(segment_index, false)):
		return
	if not _is_last_occupied(tile, segment_index):
		return
	# Catalog counts active cards, meaning occupied tiles that can still trigger.
	if _active_occupied_count_in_segment(tile, segment_index) < 6:
		return
	_closed_orbit_used[segment_index] = true
	var gain := 0.0
	for passive in get_passives(segment_index):
		if passive.effect_type == SegmentPassive.EffectType.LAYOUT_CLOSED_ORBIT:
			gain += passive.effect_value
	if gain <= 0.0:
		return
	for energy_card in tile.map.get_all_tile_cards_on_segment(segment_index, TileCard.TileCardType.PRODUCER):
		if energy_card.product != TileCard.Product.SCORE:
			continue
		energy_card.bonus_production_amount += gain
		var hex := tile.map.get_hex_for_tile_card(energy_card)
		_refresh_card_visual(hex, energy_card)


func _should_end_retrigger(tile: Hex, card: TileCard, segment_index: int) -> bool:
	if bool(_end_retrigger_used.get(segment_index, false)):
		return false
	if not _is_last_producer(tile, card, segment_index):
		return false
	return _all_earlier_occupied_activated(tile, card, segment_index)


func _is_first_producer(segment_index: int, card: TileCard) -> bool:
	if card.type != TileCard.TileCardType.PRODUCER:
		return false
	return not bool(_first_producer_fired.get(segment_index, false))


func _is_last_producer(tile: Hex, card: TileCard, segment_index: int) -> bool:
	if card.type != TileCard.TileCardType.PRODUCER:
		return false
	var last := _last_producer_in_segment(tile, segment_index)
	return last == card


func _last_producer_in_segment(tile: Hex, segment_index: int) -> TileCard:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return null
	var last: TileCard = null
	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.active_tile_card == null:
			continue
		if hex.active_tile_card.type != TileCard.TileCardType.PRODUCER:
			continue
		if not tile.map.is_tile_card_triggerable(hex):
			continue
		last = hex.active_tile_card
	return last


func _is_last_occupied(tile: Hex, segment_index: int) -> bool:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return false
	var last: Hex = null
	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.active_tile_card == null:
			continue
		if not tile.map.is_tile_card_triggerable(hex):
			continue
		last = hex
	return last == tile


func _is_numeric_producer(card: TileCard) -> bool:
	if card.type != TileCard.TileCardType.PRODUCER:
		return false
	return card.product == TileCard.Product.SCORE or card.product == TileCard.Product.MULTIPLIER or card.product == TileCard.Product.GOLD


func _note_numeric_product(segment_index: int, card: TileCard) -> void:
	if not _is_numeric_producer(card):
		return
	var seen: Array = _products_this_turn.get(segment_index, [])
	if not seen.has(card.product):
		seen.append(card.product)
	_products_this_turn[segment_index] = seen
	var previous: Variant = _last_numeric_product.get(segment_index, TileCard.Product.NONE)
	if previous != TileCard.Product.NONE and previous != card.product:
		MetaProgressionManager.add_alternating_activation()
	_last_numeric_product[segment_index] = card.product


func _alternating_bonus(segment_index: int, card: TileCard, value: float) -> float:
	if not _is_numeric_producer(card):
		return 0.0
	var previous: Variant = _last_numeric_product.get(segment_index, TileCard.Product.NONE)
	if previous == TileCard.Product.NONE or previous == card.product:
		return 0.0
	return value


func _adjacency_bonus(tile: Hex, card: TileCard, passive: SegmentPassive) -> float:
	if card.type != TileCard.TileCardType.PRODUCER:
		return 0.0
	if card.product == TileCard.Product.NONE or card.product == TileCard.Product.HYBRID:
		return 0.0
	var needed := maxi(1, passive.extra_int)
	var neighbors := 0
	for other in tile.map.get_all_adjacent_tile_cards(tile, TileCard.TileCardType.PRODUCER):
		if other.product == card.product:
			neighbors += 1
	if neighbors < needed:
		return 0.0
	return passive.effect_value


## True when this Producer would receive any adjacency output bonus.
func _qualifies_adjacency_trigger(tile: Hex, card: TileCard) -> bool:
	if card.type != TileCard.TileCardType.PRODUCER:
		return false
	for passive in get_passives(tile.map.get_segment_index(tile.coordinates)):
		if passive.effect_type != SegmentPassive.EffectType.ADJACENCY_OUTPUT_MULT:
			continue
		if _adjacency_bonus(tile, card, passive) > 0.0:
			return true
	return false


func _is_segment_fully_occupied(tile: Hex, segment_index: int) -> bool:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return false
	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.is_disabled_by_difficulty:
			continue
		if hex.active_tile_card == null:
			return false
	return true


func _qualifies_resonant_array(tile: Hex, segment_index: int) -> bool:
	if tile.map.get_segment_size(segment_index) < 6:
		return false
	if not _is_segment_fully_occupied(tile, segment_index):
		return false
	var product := TileCard.Product.NONE
	for energy_or_other in tile.map.get_all_tile_cards_on_segment(segment_index, TileCard.TileCardType.PRODUCER):
		if product == TileCard.Product.NONE:
			product = energy_or_other.product
		elif energy_or_other.product != product:
			return false
	if product == TileCard.Product.NONE:
		return false
	var occupied := _occupied_count_in_segment(tile, segment_index)
	return occupied == tile.map.get_segment_size(segment_index)


func _occupied_count_in_segment(tile: Hex, segment_index: int) -> int:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return 0
	var count := 0
	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.active_tile_card == null:
			continue
		count += 1
	return count


func _active_occupied_count_in_segment(tile: Hex, segment_index: int) -> int:
	# Occupied tiles that can still resolve. Closed Orbit keys off this count.
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return 0
	var count := 0
	for coords: Vector2i in segments[segment_index]:
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.active_tile_card == null:
			continue
		if not tile.map.is_tile_card_triggerable(hex):
			continue
		count += 1
	return count


func _earlier_occupied_count(tile: Hex, segment_index: int) -> int:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return 0
	var count := 0
	for coords: Vector2i in segments[segment_index]:
		if coords == tile.coordinates:
			break
		var hex: Hex = tile.map.map_data.get(coords)
		if hex != null and hex.active_tile_card != null:
			count += 1
	return count


func _consecutive_occupied_before(tile: Hex, segment_index: int) -> int:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return 0
	var segment: Array = segments[segment_index]
	var index := segment.find(tile.coordinates)
	if index <= 0:
		return 0
	var count := 0
	for i in range(index - 1, -1, -1):
		var hex: Hex = tile.map.map_data.get(segment[i])
		if hex == null or hex.active_tile_card == null:
			break
		count += 1
	return count


func _all_earlier_occupied_activated(tile: Hex, card: TileCard, segment_index: int) -> bool:
	var segments := tile.map.build_segments()
	if segment_index < 0 or segment_index >= segments.size():
		return false
	for coords: Vector2i in segments[segment_index]:
		if coords == tile.coordinates:
			return true
		var hex: Hex = tile.map.map_data.get(coords)
		if hex == null or hex.active_tile_card == null:
			continue
		if not GameManager.has_tile_card_activated_this_turn(hex.active_tile_card):
			return false
	return true


func _capped_bonus(raw: float, cap: float) -> float:
	if cap <= 0.0:
		return raw
	return minf(raw, cap)


func _refresh_card_visual(tile: Hex, card: TileCard) -> void:
	if tile == null:
		return
	tile.refresh_tile_card_visual_state()
