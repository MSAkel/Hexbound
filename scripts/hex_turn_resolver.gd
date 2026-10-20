class_name HexTurnResolver
extends Node

## Turn resolve, queued retriggers, floating text, and garnish FX for HexTileMap.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/animations/floating_text.tscn")
# Pause between tile card activations during turn resolution.
const TILE_ACTIVATION_PACE_DELAY := 0.1
## Fallback if the Hour readout never reports its score presentation finished.
## Covers in-flight floats landing, the Flavour x Mult merge, and the score hold.
const HOUR_SCORE_PRESENTATION_TIMEOUT := 5.0
## Extra hold on the first Hour score during the tutorial.
const TUTORIAL_SCORE_LINGER := 0.55
## Headless resolves skip animation awaits. Yield every so often so a retrigger storm cannot freeze the process.
const SKIP_PRESENTATION_YIELD_EVERY := 64
## Abort a single tile's retrigger drain after this many activations and dump the board.
const SKIP_PRESENTATION_STORM_LIMIT := 400

var map: HexTileMap
## True when skip-presentation aborted a retrigger drain at SKIP_PRESENTATION_STORM_LIMIT.
var aborted_retrigger_storm := false
# Extra rune activations queued by support runes. Resolved before tile flow continues.
var pending_trigger_queue: Array[Dictionary] = []
# Remaining chained triggers keyed by the source hex that queued them.
var _trigger_link_pending: Dictionary = {}
# Callbacks to run once the trigger link session from their source hex finishes.
var _after_trigger_link: Dictionary = {}
# First scoring row in a tutorial run holds longer.
var _did_tutorial_product_linger: bool = false
var _skip_presentation_steps := 0
var _storm_resolved := 0
var _storm_counts: Dictionary = {}
var _storm_edges: Dictionary = {}
# True while a fire queued by a staff member is resolving. Reaction staff read this to avoid loops.
var _resolving_staff_trigger := false


func setup(tile_map: HexTileMap) -> void:
	map = tile_map
	# Named methods so EventBus drops these when the resolver leaves the tree.
	EventBus.tile_card_garnished.connect(_on_tile_card_garnished)
	EventBus.tile_card_garnish_cleared.connect(_on_tile_card_garnish_cleared)


## Resolves every placed rune in trigger order when the player ends the turn.
func resolve_turn() -> void:
	map.dismiss_hover_feedback()
	map.reset_hour_results()
	aborted_retrigger_storm = false
	AudioManager.reset_card_trigger_chops()

	_resolving_staff_trigger = false
	pending_trigger_queue.clear()
	_clear_trigger_link_sessions()
	_skip_presentation_steps = 0

	var hexes := map.get_hexes_in_trigger_order()
	for tile: Hex in hexes:
		if tile.active_tile_card != null:
			tile.active_tile_card.reset_hour_product_snapshot()
	map.refresh_dish_output_chips()

	var active_segment := -1
	for tile: Hex in hexes:
		var segment_index := map.get_segment_index(tile.coordinates)
		if segment_index != active_segment:
			active_segment = segment_index
			await _start_station_staff(segment_index)

		if _should_bypass_primary_trigger_order_activation(tile):
			if _mark_segment_resolved_if_natural_pass_done(tile):
				await _finish_station_staff(segment_index)
			continue

		await _resolve_rune_activation(tile)
		await _wait_for_station_choices()
		await _wait_between_tile_activations()
		if _mark_segment_resolved_if_natural_pass_done(tile):
			await _finish_station_staff(segment_index)

	if not GameManager.skip_presentation:
		await _present_hour_score()
	map._apply_segment_turn_totals_to_game_manager()
	_clear_hour_garnish()
	StaffManager.end_hour()
	await GameManager.finish_turn_processing()


## A served Meal can push a station to level 3. The Hour pauses until every pick is made.
func _wait_for_station_choices() -> void:
	while StationManager.has_pending_choice():
		await StationManager.choice_resolved


## The staff member linked to this station acts before its first spot fires.
func _start_station_staff(segment_index: int) -> void:
	if not StaffManager.station_started(map, segment_index):
		return
	await _wait_for_activation_animation()
	await _wait_between_tile_activations()


## The staff member linked to this station acts once its last spot and retriggers are done.
func _finish_station_staff(segment_index: int) -> void:
	if not StaffManager.station_finished(map, segment_index):
		return
	await _wait_for_activation_animation()
	await _wait_between_tile_activations()


# Resolve one tile: primary activation, then any queued secondary triggers.
func _resolve_rune_activation(tile: Hex) -> void:
	_reset_storm_tracking()
	await _activate_tile_card_on_tile(tile, 1.0, false)

	while not pending_trigger_queue.is_empty():
		var entry: Dictionary = pending_trigger_queue.pop_front()
		var source_hex: Hex = entry.get("source_hex") as Hex
		var target_hex := map.get_hex_for_tile_card(entry["rune"])
		if target_hex == null or target_hex.active_tile_card == null:
			_resolve_trigger_link_entry(entry)
			continue
		if not _would_activate_tile_card_on_tile(target_hex, true):
			_resolve_trigger_link_entry(entry)
			continue
		await _wait_between_tile_activations()
		await _activate_tile_card_on_tile(
			target_hex,
			entry["activation_scale"],
			true,
			source_hex,
			int(entry.get("staff_slot", -1)),
		)
		_resolve_trigger_link_entry(entry)
		if _note_storm_activation(source_hex, target_hex):
			aborted_retrigger_storm = true
			push_warning("HexTurnResolver: retrigger storm aborted after %d activations." % SKIP_PRESENTATION_STORM_LIMIT)
			pending_trigger_queue.clear()
			break
		await _yield_if_skip_presentation()


func _reset_storm_tracking() -> void:
	_storm_resolved = 0
	_storm_counts.clear()
	_storm_edges.clear()


## Counts one queued activation. True when the skip-presentation safety cap tripped.
func _note_storm_activation(source_hex: Hex, target_hex: Hex) -> bool:
	if not GameManager.skip_presentation:
		return false
	_storm_resolved += 1
	var target_id := "?"
	if target_hex != null and target_hex.active_tile_card != null:
		target_id = target_hex.active_tile_card.id
	_storm_counts[target_id] = int(_storm_counts.get(target_id, 0)) + 1
	var source_id := "?"
	if source_hex != null and source_hex.active_tile_card != null:
		source_id = source_hex.active_tile_card.id
	var edge := "%s -> %s" % [source_id, target_id]
	_storm_edges[edge] = int(_storm_edges.get(edge, 0)) + 1
	if _storm_resolved != SKIP_PRESENTATION_STORM_LIMIT:
		return false
	_dump_retrigger_storm()
	return true


func _dump_retrigger_storm() -> void:
	print("[playtest] RETRIGGER STORM round=%d activations=%d queue=%d" % [
		GameManager.current_round,
		_storm_resolved,
		pending_trigger_queue.size(),
	])
	var count_keys: Array = _storm_counts.keys()
	count_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca := int(_storm_counts[a])
		var cb := int(_storm_counts[b])
		if ca != cb:
			return ca > cb
		return str(a) < str(b)
	)
	for key: Variant in count_keys:
		print("[playtest]   fired %s x%d" % [str(key), int(_storm_counts[key])])
	var edge_keys: Array = _storm_edges.keys()
	edge_keys.sort_custom(func(a: Variant, b: Variant) -> bool:
		var ca := int(_storm_edges[a])
		var cb := int(_storm_edges[b])
		if ca != cb:
			return ca > cb
		return str(a) < str(b)
	)
	var shown := 0
	for key: Variant in edge_keys:
		print("[playtest]   edge %s x%d" % [str(key), int(_storm_edges[key])])
		shown += 1
		if shown >= 12:
			break
	if map == null:
		return
	print("[playtest]   board:")
	for hex: Hex in map.get_hexes_in_trigger_order():
		if hex.active_tile_card == null:
			continue
		print(
			"[playtest]     seg=%d %s %s %s"
			% [
				map.get_segment_index(hex.coordinates),
				str(hex.coordinates),
				hex.active_tile_card.id,
				_card_type_label(hex.active_tile_card),
			]
		)


func _card_type_label(card: TileCard) -> String:
	match card.type:
		TileCard.TileCardType.INGREDIENT:
			return "ingredients"
		TileCard.TileCardType.KITCHENWARE:
			return "kitchenware"
		TileCard.TileCardType.MEAL:
			return "meal"
		_:
			return "other"


func _yield_if_skip_presentation() -> void:
	if not GameManager.skip_presentation:
		return
	_skip_presentation_steps += 1
	if _skip_presentation_steps < SKIP_PRESENTATION_YIELD_EVERY:
		return
	_skip_presentation_steps = 0
	await get_tree().process_frame


func _activate_tile_card_on_tile(
	tile: Hex,
	activation_scale: float = 1.0,
	from_trigger: bool = false,
	trigger_source_hex: Hex = null,
	staff_slot: int = -1,
) -> void:
	if not _would_activate_tile_card_on_tile(tile, from_trigger):
		return

	activation_scale *= EventManager.get_producer_output_multiplier(tile)

	if from_trigger and staff_slot >= 0:
		if not GameManager.skip_presentation:
			map.play_staff_bolt(staff_slot, tile)
			tile.play_chained_tile_card_activation_animation()
	elif from_trigger and trigger_source_hex != null:
		if not GameManager.skip_presentation:
			map.trigger_link_overlay.play_bolt(trigger_source_hex, tile)
			tile.play_chained_tile_card_activation_animation()
	elif not GameManager.skip_presentation:
		tile.play_tile_card_activation_animation()
	await _wait_for_activation_animation()

	_resolving_staff_trigger = staff_slot >= 0
	tile.apply_tile_card_activation(activation_scale)
	_resolving_staff_trigger = false


func is_resolving_staff_trigger() -> bool:
	return _resolving_staff_trigger


func _should_bypass_primary_trigger_order_activation(tile: Hex) -> bool:
	return not map.is_tile_card_active(tile)


## Close the segment once no later tile in that line still has a primary activation waiting.
## Returns true when this call closed it.
func _mark_segment_resolved_if_natural_pass_done(current: Hex) -> bool:
	var segment_index := map.get_segment_index(current.coordinates)
	if segment_index < 0:
		return false
	var seen_current := false
	for hex: Hex in map.get_hexes_in_segment(segment_index):
		if hex == current:
			seen_current = true
			continue
		if not seen_current:
			continue
		if map.is_tile_card_active(hex):
			return false
	return map.mark_segment_resolved(segment_index)


func _would_activate_tile_card_on_tile(tile: Hex, from_trigger: bool) -> bool:
	if not map.is_tile_card_active(tile):
		return false
	var card := tile.active_tile_card
	if card.can_be_triggered_by_other_card(tile):
		return true
	# Locked cards (Overdrive, or Mirror Copy copying it) only fire from trigger order once.
	if from_trigger:
		return false
	return not GameManager.has_tile_card_activated_this_turn(card)


func _wait_for_activation_animation() -> void:
	await _wait_pace(CardIconUI.activation_animation_duration())


func _wait_between_tile_activations() -> void:
	await _wait_pace(TILE_ACTIVATION_PACE_DELAY)


func _wait_pace(duration: float) -> void:
	if GameManager.skip_presentation:
		return
	var timer := GameManager.create_pauseable_timer(duration / GameManager.game_speed)
	while timer.time_left > 0.0:
		if not is_inside_tree():
			return
		await get_tree().process_frame


## Hands the Hour's Flavour x Mult to the readout, then waits for its merge and hold.
## Times out so a missed UI signal cannot stall the turn.
func _present_hour_score() -> void:
	var flavour := map.get_hour_flavour()
	var mult := map.get_hour_additive_mult()
	var score := GameManager.compute_hour_turn_contribution(flavour, mult)

	var state := {"done": false}
	var on_finished := func() -> void:
		state.done = true
	EventBus.hour_score_presentation_finished.connect(on_finished)
	var timer := GameManager.create_pauseable_timer(
		HOUR_SCORE_PRESENTATION_TIMEOUT / GameManager.game_speed
	)
	timer.timeout.connect(func() -> void: state.done = true)
	EventBus.hour_score_presentation_requested.emit(flavour, mult, score)
	while not state.done and is_inside_tree():
		await get_tree().process_frame
	if EventBus.hour_score_presentation_finished.is_connected(on_finished):
		EventBus.hour_score_presentation_finished.disconnect(on_finished)

	if score > 0 and _should_linger_on_product():
		await _wait_pace(TUTORIAL_SCORE_LINGER)


## The player's first ever Hour score holds longer so it can be read before the card pick.
func _should_linger_on_product() -> bool:
	if _did_tutorial_product_linger:
		return false
	if not TutorialManager.is_live() or TutorialManager.is_seen(&"card_pick_choose"):
		return false
	_did_tutorial_product_linger = true
	return true
	for node in get_tree().get_nodes_in_group("tutorial_banner"):
		if node.has_method("is_tutorial_active") and node.is_tutorial_active():
			_did_tutorial_product_linger = true
			return true
	return false


## Removes a placed rune from its tile and cancels queued triggers targeting it.
func destroy_placed_tile_card(rune: TileCard) -> void:
	var hex := map.get_hex_for_tile_card(rune)
	if hex == null:
		return

	hex.remove_tile_card()

	if _after_trigger_link.has(hex):
		_after_trigger_link.erase(hex)

	for i in range(pending_trigger_queue.size() - 1, -1, -1):
		if pending_trigger_queue[i]["rune"] == rune:
			_resolve_trigger_link_entry(pending_trigger_queue[i])
			pending_trigger_queue.remove_at(i)

	if _trigger_link_pending.has(hex):
		_clear_trigger_link_session(hex)


## Queues extra rune activations to resolve before the current tile flow continues.
## staff_slot is set when a staff member, not a seated card, asked for the fire.
## Returns how many activations were actually queued.
func queue_tile_card_triggers(
	runes: Array[TileCard],
	activation_scales: Array[float] = [],
	source_hex: Hex = null,
	staff_slot: int = -1,
) -> int:
	var queued := 0
	for i in range(runes.size()):
		var target_hex := map.get_hex_for_tile_card(runes[i])
		if target_hex == null or not map.is_tile_card_triggerable(target_hex):
			continue
		# Finished segments stay closed. Do not retrigger cards on them.
		if map.is_segment_resolved(map.get_segment_index(target_hex.coordinates)):
			continue

		var scale_rune := 1.0
		if i < activation_scales.size():
			scale_rune = activation_scales[i]
		var entry := {
			"rune": runes[i],
			"activation_scale": scale_rune,
			"source_hex": source_hex,
			"staff_slot": staff_slot,
		}
		pending_trigger_queue.append(entry)
		queued += 1
		if source_hex != null:
			_register_trigger_link_pending(source_hex)
	return queued


## Extra fires requested by the staff member in staff_slot. The bolt starts at that staff member's hex.
func queue_staff_triggers(runes: Array[TileCard], staff_slot: int) -> int:
	return queue_tile_card_triggers(runes, [], null, staff_slot)


## Runs callback after every trigger queued from source_hex resolves.
## Dropped if the card on source_hex is destroyed first.
func run_after_trigger_link(source_hex: Hex, callback: Callable) -> void:
	if source_hex == null or not callback.is_valid():
		return
	_after_trigger_link[source_hex] = callback


func _register_trigger_link_pending(source_hex: Hex) -> void:
	if source_hex == null:
		return

	var pending_count: int = int(_trigger_link_pending.get(source_hex, 0))
	if pending_count == 0:
		source_hex.start_trigger_link_flash()
	_trigger_link_pending[source_hex] = pending_count + 1


func _resolve_trigger_link_entry(entry: Dictionary) -> void:
	var source_hex: Variant = entry.get("source_hex")
	if source_hex == null or not (source_hex is Hex):
		return
	if not _trigger_link_pending.has(source_hex):
		return

	var pending_count: int = int(_trigger_link_pending[source_hex]) - 1
	if pending_count <= 0:
		_clear_trigger_link_session(source_hex)
	else:
		_trigger_link_pending[source_hex] = pending_count


func _clear_trigger_link_session(source_hex: Hex) -> void:
	if source_hex == null:
		return
	_trigger_link_pending.erase(source_hex)
	if source_hex.is_on_map():
		source_hex.stop_trigger_link_flash()
	_run_after_trigger_link(source_hex)


func _run_after_trigger_link(source_hex: Hex) -> void:
	if not _after_trigger_link.has(source_hex):
		return

	var callback: Callable = _after_trigger_link[source_hex]
	_after_trigger_link.erase(source_hex)
	if callback.is_valid():
		callback.call()


func _clear_trigger_link_sessions() -> void:
	for source_hex: Hex in _trigger_link_pending.keys():
		if source_hex != null and source_hex.is_on_map():
			source_hex.stop_trigger_link_flash()
	_trigger_link_pending.clear()
	_after_trigger_link.clear()


## Show floating text at a world position, converted onto the screen-space float layer.
func create_floating_text(
	pos: Vector2,
	text: String,
	color: Color = Color.WHITE,
	icon: Texture2D = null,
	target_icon: Texture2D = null,
	garnished: bool = false
) -> void:
	if GameManager.skip_presentation:
		return
	var floating_text := _spawn_floating_text(pos, text, color, icon, target_icon, garnished)
	var readout := HourScoreReadout.find_accepting(get_tree())
	var product := HourScoreReadout.product_for_float(icon, target_icon)
	if readout != null and product != HourScoreReadout.Product.NONE:
		floating_text.play_float_and_absorb(readout, product, readout.reserve(product))
	else:
		floating_text.play_float_and_free()


func _spawn_floating_text(
	pos: Vector2,
	text: String,
	color: Color,
	icon: Texture2D = null,
	target_icon: Texture2D = null,
	garnished: bool = false
) -> FloatingText:
	var floating_text := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	floating_text.position = _world_to_floating_text_screen(pos)
	_get_floating_text_layer().add_child(floating_text)
	floating_text.set_text(text, color, icon, target_icon, garnished)
	return floating_text


## Convert a world-space hex center into CanvasLayer viewport pixels.
func _world_to_floating_text_screen(world_pos: Vector2) -> Vector2:
	var viewport := get_viewport()
	if viewport == null:
		return world_pos
	return viewport.get_canvas_transform() * world_pos


func _get_floating_text_layer() -> Node:
	var scene := get_tree().current_scene
	if scene != null:
		var layer := scene.get_node_or_null("FloatingTextLayer")
		if layer != null:
			return layer
		return scene
	return map


func _on_tile_card_garnished(rune: TileCard) -> void:
	var hex := map.get_hex_for_tile_card(rune)
	if hex == null:
		AudioManager.play_sfx(UISounds.GARNISH)
		return

	if GameManager.skip_presentation:
		if hex != null and hex.is_on_map() and hex.active_tile_card == rune and rune.is_garnished:
			hex.start_garnish_sparks(rune.garnish_stacks)
		return

	# Strike first, then the looping overcharge. Same beat as a retrigger bolt landing.
	var strike_travel := map.trigger_link_overlay.play_garnish_strike(hex)
	await _wait_pace(strike_travel)
	if hex == null or not hex.is_on_map() or hex.active_tile_card != rune or not rune.is_garnished:
		return

	AudioManager.play_sfx(UISounds.GARNISH)
	hex.start_garnish_sparks(rune.garnish_stacks)


## Staff such as the Pickler can let a card keep some stacks into the next Hour.
func _clear_hour_garnish() -> void:
	for tile: Hex in map.get_all_hexes_with_runes():
		var card := tile.active_tile_card
		if card == null:
			continue
		card.trim_garnish(StaffManager.garnish_kept_after_hour(card))
		if card.is_garnished:
			tile.start_garnish_sparks(card.garnish_stacks)


func _on_tile_card_garnish_cleared(rune: TileCard) -> void:
	var hex := map.get_hex_for_tile_card(rune)
	if hex != null:
		hex.stop_garnish_sparks()
