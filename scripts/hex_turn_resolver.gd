class_name HexTurnResolver
extends Node

## Turn resolve, queued retriggers, floating text, and empower FX for HexTileMap.

const FLOATING_TEXT_SCENE: PackedScene = preload("res://scenes/animations/floating_text.tscn")
# Pause between tile card activations during turn resolution.
const TILE_ACTIVATION_PACE_DELAY := 0.5
const SEGMENT_REVEAL_PAUSE := 0.35
# Keep in sync with RuneUI segment reveal highlight and fade durations.
const SEGMENT_REVEAL_ANIMATION_DURATION := 0.36
## Fallback if the score-breakdown row never emits count-finished (killed or already-done tween).
const SEGMENT_SCORE_COUNT_TIMEOUT := 2.0
## Fallback if the turn-total footer never emits count-finished.
const TURN_TOTAL_COUNT_TIMEOUT := 2.0
## Extra hold on the first scoring row during the tutorial.
const TUTORIAL_SCORE_LINGER := 0.55
## Headless resolves skip animation awaits. Yield every so often so a retrigger storm cannot freeze the process.
const SKIP_PRESENTATION_YIELD_EVERY := 64
## Abort a single tile's retrigger drain after this many activations and dump the board.
const SKIP_PRESENTATION_STORM_LIMIT := 400

var map: HexTileMap
# Extra rune activations queued by support runes. Resolved before tile flow continues.
var pending_trigger_queue: Array[Dictionary] = []
# Remaining chained triggers keyed by the source hex that queued them.
var _trigger_link_pending: Dictionary = {}
# Tile cards that should be removed once their queued trigger link session finishes.
var _deferred_destroy_after_triggers: Dictionary = {}
# First scoring row in a tutorial run holds longer.
var _did_tutorial_product_linger: bool = false
var _skip_presentation_steps := 0
var _storm_resolved := 0
var _storm_counts: Dictionary = {}
var _storm_edges: Dictionary = {}


func setup(tile_map: HexTileMap) -> void:
	map = tile_map
	# Named methods so EventBus drops these when the resolver leaves the tree.
	EventBus.tile_card_empowered.connect(_on_tile_card_empowered)
	EventBus.tile_card_empower_consumed.connect(_on_tile_card_empower_consumed)


## Resolves every placed rune in trigger order when the player ends the turn.
func resolve_turn() -> void:
	map.dismiss_hover_feedback()
	map.reset_segment_turn_results()

	pending_trigger_queue.clear()
	_clear_trigger_link_sessions()
	_skip_presentation_steps = 0

	for tile: Hex in map.get_hexes_in_trigger_order():
		if _should_bypass_primary_trigger_order_activation(tile):
			_mark_segment_resolved_if_natural_pass_done(tile)
			continue

		await _resolve_rune_activation(tile)
		await _wait_between_tile_activations()
		_mark_segment_resolved_if_natural_pass_done(tile)

	if GameManager.should_skip_turn_presentation():
		EventBus.segment_reveals_finished.emit(_sum_segment_contributions())
	else:
		await _play_segment_turn_result_reveals()
		await _wait_for_turn_total_count_finished()
	map._apply_segment_turn_totals_to_game_manager()
	map._check_full_map_cards_achievement()
	map._emit_segment_turn_completed_snapshot()
	await GameManager.finish_turn_processing()


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
		)
		_resolve_trigger_link_entry(entry)
		if _note_storm_activation(source_hex, target_hex):
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
		TileCard.TileCardType.PRODUCER:
			return "producer"
		TileCard.TileCardType.SUPPORT:
			return "support"
		TileCard.TileCardType.UTILITY:
			return "utility"
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
) -> void:
	if not _would_activate_tile_card_on_tile(tile, from_trigger):
		return

	activation_scale *= EventManager.get_producer_output_multiplier(tile)

	if from_trigger and trigger_source_hex != null:
		if not GameManager.should_skip_turn_presentation():
			map.trigger_link_overlay.play_bolt(trigger_source_hex, tile)
			tile.play_chained_tile_card_activation_animation()
	elif not GameManager.should_skip_turn_presentation():
		tile.play_tile_card_activation_animation()
	await _wait_for_activation_animation()

	tile.apply_tile_card_activation(activation_scale)


func _should_bypass_primary_trigger_order_activation(tile: Hex) -> bool:
	return not map.is_tile_card_active(tile)


## Close the segment once no later tile in that line still has a primary activation waiting.
func _mark_segment_resolved_if_natural_pass_done(current: Hex) -> void:
	var segment_index := map.get_segment_index(current.coordinates)
	if segment_index < 0:
		return
	var seen_current := false
	for hex: Hex in map.get_hexes_in_trigger_order():
		if hex == current:
			seen_current = true
			continue
		if not seen_current:
			continue
		if map.get_segment_index(hex.coordinates) != segment_index:
			break
		if map.is_tile_card_active(hex):
			return
	map.mark_segment_resolved(segment_index)


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
	await _wait_pace(RuneUI.activation_animation_duration())


func _wait_between_tile_activations() -> void:
	await _wait_pace(TILE_ACTIVATION_PACE_DELAY)


func _wait_pace(duration: float) -> void:
	if GameManager.should_skip_turn_presentation():
		return
	var timer := GameManager.create_pauseable_timer(duration / GameManager.game_speed)
	while timer.time_left > 0.0:
		if GameManager.should_skip_turn_presentation():
			return
		if not is_inside_tree():
			return
		await get_tree().process_frame


## Energy x Mult summed across segments. Used when reveal UI is skipped.
func _sum_segment_contributions() -> int:
	var total := 0
	for segment_index in map.get_segment_count():
		total += GameManager.compute_segment_turn_contribution(
			segment_index,
			map.get_segment_turn_score(segment_index),
			map.get_segment_turn_multiplier(segment_index)
		)
	return total


## Plays the end-of-turn reveal for each segment that produced score, multiplier, or gold this turn.
func _play_segment_turn_result_reveals() -> void:
	var turn_total := 0
	for segment_index in map.get_segment_count():
		if GameManager.should_skip_turn_presentation():
			break
		var score := map.get_segment_turn_score(segment_index)
		var multiplier := map.get_segment_turn_multiplier(segment_index)
		var gold := map.get_segment_turn_gold(segment_index)
		if score == 0 and gold == 0:
			continue
		var contribution := GameManager.compute_segment_turn_contribution(
			segment_index,
			score,
			multiplier
		)
		turn_total += contribution
		await _play_single_segment_reveal(segment_index, contribution)

	if GameManager.should_skip_turn_presentation():
		map._clear_segment_reveal_glow()
		EventBus.segment_reveals_finished.emit(_sum_segment_contributions())
		return

	EventBus.segment_reveals_finished.emit(turn_total)


## Highlights one segment on the map and in the output panel, then reveals that segment's Score.
func _play_single_segment_reveal(segment_index: int, contribution: int) -> void:
	if GameManager.should_skip_turn_presentation():
		return
	map._apply_segment_reveal_glow(segment_index)
	EventBus.segment_reveal_started.emit(segment_index)

	for hex: Hex in map.get_hexes_in_segment(segment_index):
		if hex.active_tile_card != null:
			hex.play_segment_result_animation()

	await _wait_pace(SEGMENT_REVEAL_ANIMATION_DURATION)

	if contribution > 0:
		# Show passive-adjusted power before the equals beat lands.
		map._emit_segment_turn_results_changed(segment_index, true)
		EventBus.segment_score_revealed.emit(segment_index, contribution)
		await _wait_for_segment_score_count_finished(segment_index)
		if _should_linger_on_product():
			await _wait_pace(TUTORIAL_SCORE_LINGER)

	await _wait_pace(SEGMENT_REVEAL_PAUSE)
	map._clear_segment_reveal_glow()
	EventBus.segment_reveal_ended.emit()
	await _wait_pace(SEGMENT_REVEAL_PAUSE)


## Waits for this segment's Score count. Times out so a missed UI signal cannot stall the turn.
func _wait_for_segment_score_count_finished(segment_index: int) -> void:
	var state := {"done": false}
	var on_finished := func(finished_index: int) -> void:
		if finished_index == segment_index:
			state.done = true
	EventBus.segment_score_count_finished.connect(on_finished)
	var timer := GameManager.create_pauseable_timer(
		SEGMENT_SCORE_COUNT_TIMEOUT / GameManager.game_speed
	)
	timer.timeout.connect(func() -> void: state.done = true)
	while not state.done and is_inside_tree():
		if GameManager.should_skip_turn_presentation():
			return
		await get_tree().process_frame
	if EventBus.segment_score_count_finished.is_connected(on_finished):
		EventBus.segment_score_count_finished.disconnect(on_finished)


## Waits for the turn-total footer count. Times out so a missed UI signal cannot stall the turn.
func _wait_for_turn_total_count_finished() -> void:
	var state := {"done": false}
	var on_finished := func() -> void:
		state.done = true
	EventBus.turn_total_count_finished.connect(on_finished)
	var timer := GameManager.create_pauseable_timer(
		TURN_TOTAL_COUNT_TIMEOUT / GameManager.game_speed
	)
	timer.timeout.connect(func() -> void: state.done = true)
	while not state.done and is_inside_tree():
		if GameManager.should_skip_turn_presentation():
			return
		await get_tree().process_frame
	if EventBus.turn_total_count_finished.is_connected(on_finished):
		EventBus.turn_total_count_finished.disconnect(on_finished)


## First scoring beat in an active tutorial holds longer so the output row can be read.
func _should_linger_on_product() -> bool:
	if _did_tutorial_product_linger:
		return false
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

	if _deferred_destroy_after_triggers.has(hex):
		_deferred_destroy_after_triggers.erase(hex)

	for i in range(pending_trigger_queue.size() - 1, -1, -1):
		if pending_trigger_queue[i]["rune"] == rune:
			_resolve_trigger_link_entry(pending_trigger_queue[i])
			pending_trigger_queue.remove_at(i)

	if _trigger_link_pending.has(hex):
		_clear_trigger_link_session(hex)


## Queues extra rune activations to resolve before the current tile flow continues.
func queue_tile_card_triggers(
	runes: Array[TileCard],
	activation_scales: Array[float] = [],
	source_hex: Hex = null,
) -> void:
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
		}
		pending_trigger_queue.append(entry)
		if source_hex != null:
			_register_trigger_link_pending(source_hex)


## Removes tile_card from the map after every trigger queued from source_hex resolves.
func schedule_destroy_after_trigger_link(
	source_hex: Hex,
	tile_card: TileCard,
	on_destroy: Callable = Callable(),
) -> void:
	if source_hex == null or tile_card == null:
		return
	_deferred_destroy_after_triggers[source_hex] = {
		"tile_card": tile_card,
		"on_destroy": on_destroy,
	}


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
	_run_deferred_destroy_after_trigger_link(source_hex)


func _run_deferred_destroy_after_trigger_link(source_hex: Hex) -> void:
	if not _deferred_destroy_after_triggers.has(source_hex):
		return

	var pending: Dictionary = _deferred_destroy_after_triggers[source_hex]
	_deferred_destroy_after_triggers.erase(source_hex)

	var tile_card: TileCard = pending.get("tile_card")
	if tile_card != null:
		destroy_placed_tile_card(tile_card)

	var on_destroy: Callable = pending.get("on_destroy", Callable())
	if on_destroy.is_valid():
		on_destroy.call()


func _clear_trigger_link_sessions() -> void:
	for source_hex: Hex in _trigger_link_pending.keys():
		if source_hex != null and source_hex.is_on_map():
			source_hex.stop_trigger_link_flash()
	_trigger_link_pending.clear()
	_deferred_destroy_after_triggers.clear()


## Show floating text at a world position on the current scene.
func create_floating_text(pos: Vector2, text: String, color: Color = Color.WHITE, icon: Texture2D = null) -> void:
	if GameManager.should_skip_turn_presentation():
		return
	var floating_text := _spawn_floating_text(pos, text, color, icon)
	floating_text.play_float_and_free()


func _spawn_floating_text(pos: Vector2, text: String, color: Color, icon: Texture2D = null) -> FloatingText:
	var floating_text := FLOATING_TEXT_SCENE.instantiate() as FloatingText
	floating_text.position = pos
	get_tree().current_scene.add_child(floating_text)
	floating_text.set_text(text, color, icon)
	return floating_text


func _on_tile_card_empowered(rune: TileCard) -> void:
	var hex := map.get_hex_for_tile_card(rune)
	if hex == null:
		AudioManager.play_sfx(UISounds.EMPOWER)
		return

	if GameManager.should_skip_turn_presentation():
		if hex != null and hex.is_on_map() and hex.active_tile_card == rune and rune.is_empowered:
			hex.start_empower_sparks()
		return

	# Strike first, then the looping overcharge. Same beat as a retrigger bolt landing.
	var strike_travel := map.trigger_link_overlay.play_empower_strike(hex)
	await _wait_pace(strike_travel)
	if hex == null or not hex.is_on_map() or hex.active_tile_card != rune or not rune.is_empowered:
		return

	AudioManager.play_sfx(UISounds.EMPOWER)
	hex.start_empower_sparks()


func _on_tile_card_empower_consumed(rune: TileCard) -> void:
	var hex := map.get_hex_for_tile_card(rune)
	if hex != null:
		hex.stop_empower_sparks()
