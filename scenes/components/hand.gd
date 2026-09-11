class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
## Slide the hand off-screen between turns using 4.7 offset transforms (layout-safe).
const HAND_SLIDE_DURATION := 0.35
## Stagger between each card during the run-start entrance from below.
const INTRO_CARD_STAGGER := 0.07
## Hands larger than this pack tighter toward a five-card footprint.
const SPACED_HAND_COUNT := 5
## Negative separation for small hands so the fan overlaps like a full grip.
const HAND_SLIGHT_OVERLAP_SEPARATION := -18
## Never overlap so far that a card is left with a sliver too small to click.
const MIN_VISIBLE_CARD_WIDTH := 56.0
## Extra gap opened around a featured card so the 1.2 hover scale does not cover neighbors.
const HOVER_PUSH_PADDING := 10.0
## Adjacent cards take full push. Farther cards ease off with this exponent.
const HOVER_SPREAD_FALLOFF_POWER := 0.85
## Extra fan tilt on neighbors while a card is featured.
const HOVER_SPREAD_MAX_ROTATION_DEG := 3.5
## Fallback width before a card has been laid out.
const DEFAULT_CARD_WIDTH := 214.0

## Debug-only cards appended to the opening hand.
@export_group("Debug Starting Hand")
@export var debug_starting_runes: Array[TileCard] = []

@onready var _generated_reveal: GeneratedCardReveal = $"../GeneratedCardReveal"

## Keep starting cards parked off-screen until Main finishes fade/zoom.
var _awaiting_intro := true
## True while the hand is slid below the viewport (intro or turn resolution).
var _hand_hidden := true
var _hand_slide_tween: Tween = null
## Theme separation before overlap packing is applied.
var _base_separation := 0
## Card currently lifted in the hand, if any.
var _featured_card: CardUI = null
## Lets the next hovered card claim featured before neighbors collapse to rest.
var _spread_clear_pending := false
## Index of the hand card highlighted by controller navigation.
var _controller_focus_index := -1
## Hand card currently selected for map placement.
var _placement_focus_card: CardUI = null
## True while non-selected siblings are slid off-screen for placement.
var _siblings_hidden_for_placement := false
var _sibling_slide_tween: Tween = null
## Bumped to drop stale deferred sibling restores after a new drag starts.
var _sibling_restore_generation := 0

## Reparent cards to hand when they are dragged or released
func _ready() -> void:
	_base_separation = get_theme_constant("separation")
	EventBus.card_played.connect(_on_card_played)
	EventBus.card_sold.connect(_on_card_sold)
	EventBus.tile_card_selected.connect(_add_tile_card)
	EventBus.card_drag_started.connect(_on_card_drag_started)
	EventBus.card_drag_ended.connect(_on_card_drag_ended)
	EventBus.turn_ended.connect(_hide_hand)
	EventBus.turn_started.connect(_show_hand)
	add_to_group("run_hand")

	## Saved runs rebuild the hand after the main scene finishes loading.
	if RunSaveManager.should_restore_run():
		return


## Deal the opening hand after run RNG has been seeded and setup rolls have finished.
func build_starting_hand() -> void:
	if RunSaveManager.should_restore_run():
		return

	var character := GameManager.selected_character
	if character == null:
		return

	var stream_name := "starting_hand:%s:%d" % [
		character.id,
		int(GameManager.selected_difficulty),
	]
	RunRng.using_fresh_stream(stream_name, func() -> void:
		var starting_cards := PlayerCharacter.get_starting_hand_cards(character)
		for card in starting_cards:
			_add_tile_card(card)

		_add_debug_starting_cards()

		if _awaiting_intro:
			_snap_hand_offscreen()
	)


func _notification(what: int) -> void:
	if what == NOTIFICATION_CHILD_ORDER_CHANGED:
		call_deferred("_refresh_hand_layout")


## Extra inspector cards for testing a specific rune without merchant luck.
func _add_debug_starting_cards() -> void:
	if not OS.is_debug_build():
		return

	for rune in debug_starting_runes:
		if rune != null:
			_add_tile_card(rune)


func _add_tile_card(rune: TileCard) -> void:
	_add_card(rune)


func create_hand_card(data: Card) -> CardUI:
	return _add_card(data)


func _add_card(data: Card) -> CardUI:
	var new_rune_card := CARD_UI_SCENE.instantiate() as CardUI
	new_rune_card.configure_interaction(CardUI.InteractionMode.HAND)
	add_child(new_rune_card)
	new_rune_card.set_card(data)
	new_rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, _get_hand_card_count())
		move_child.call_deferred(child, new_index)
	)
	# Cards dealt during intro or while the hand is slid away stay below the viewport.
	if _awaiting_intro or _hand_hidden:
		_snap_card_offscreen(new_rune_card)
	call_deferred("_refresh_hand_layout")
	return new_rune_card


## Guard against non-card children
func get_hand_card_count() -> int:
	return _get_hand_cards().size()


## Remove every hand card before a new pack is dealt at hour end.
func discard_all_cards() -> void:
	_generated_reveal.interrupt()
	_featured_card = null
	_controller_focus_index = -1
	_reset_placement_sibling_slide_state()
	for child in get_children():
		if child is CardUI:
			remove_child(child)
			child.queue_free()
	call_deferred("_refresh_hand_layout")


func _get_hand_card_count() -> int:
	return get_hand_card_count()


## True after a play that should auto-end the turn, before resolve starts.
## Saving here would persist a 2-card hand with no draft and no resolve.
func has_pending_auto_end() -> bool:
	return cards_played > 0 and get_hand_card_count() < 3


func _get_hand_cards() -> Array[CardUI]:
	var cards: Array[CardUI] = []
	for child in get_children():
		if child is CardUI:
			cards.append(child as CardUI)
	return cards


# Called from CardUI when a hand card lifts or settles so neighbors can slide aside.
func notify_card_featured(card: CardUI, featured: bool, animate: bool = true) -> void:
	if featured:
		_spread_clear_pending = false
		_featured_card = card
		_apply_hover_spread(animate)
		return
	if _featured_card != card:
		return
	_featured_card = null
	if not animate:
		_spread_clear_pending = false
		_apply_hover_spread(false)
		return
	# Defer the collapse one frame so moving A -> B does not snap the fan shut first.
	if _spread_clear_pending:
		return
	_spread_clear_pending = true
	call_deferred("_finish_unfeature_spread")


func _finish_unfeature_spread() -> void:
	_spread_clear_pending = false
	if _featured_card != null:
		return
	_apply_hover_spread(true)


func _refresh_hand_layout() -> void:
	if not is_inside_tree():
		return
	if _featured_card != null and _featured_card.get_parent() != self:
		_featured_card = null
	var cards := _get_hand_cards()
	if _controller_focus_index >= cards.size():
		_controller_focus_index = cards.size() - 1 if not cards.is_empty() else -1
	_update_card_overlap()
	if InputManager.is_using_gamepad():
		_apply_controller_focus_visual()
	else:
		_apply_hover_spread(true)


func move_controller_focus(direction: int) -> void:
	var cards := _get_hand_cards()
	if cards.is_empty():
		_controller_focus_index = -1
		_apply_controller_focus_visual()
		return
	if _controller_focus_index < 0:
		_controller_focus_index = 0 if direction >= 0 else cards.size() - 1
	else:
		_controller_focus_index = clampi(_controller_focus_index + direction, 0, cards.size() - 1)
	_apply_controller_focus_visual()


func ensure_controller_focus() -> void:
	var cards := _get_hand_cards()
	if cards.is_empty():
		_controller_focus_index = -1
		_apply_controller_focus_visual()
		return
	if _controller_focus_index < 0 or _controller_focus_index >= cards.size():
		_controller_focus_index = 0
	_apply_controller_focus_visual()


func clear_controller_focus() -> void:
	_controller_focus_index = -1
	for card in _get_hand_cards():
		if _should_keep_card_elevated(card) or card.is_mouse_over():
			continue
		card.set_hover_elevated(false, true)
	# Collapse neighbor spread. Placement keeps the picked card lifted without fanning the hand.
	_apply_hover_spread(true)


func get_controller_focused_card() -> CardUI:
	var cards := _get_hand_cards()
	if _controller_focus_index < 0 or _controller_focus_index >= cards.size():
		return null
	return cards[_controller_focus_index]


func _apply_controller_focus_visual() -> void:
	if not InputManager.is_using_gamepad():
		return
	var focused := get_controller_focused_card()
	for card in _get_hand_cards():
		if card == focused:
			card.set_hover_elevated(true, true)
		elif not _should_keep_card_elevated(card):
			card.set_hover_elevated(false, true)


## Placement selection keeps its lift even when controller focus moves to the map.
func _should_keep_card_elevated(card: CardUI) -> bool:
	var state_machine := card.card_state_machine
	if state_machine == null or state_machine.current_state == null:
		return false
	return state_machine.current_state.state == CardState.State.CLICKED


func _update_card_overlap() -> void:
	add_theme_constant_override("separation", _compute_hand_separation())


func _compute_hand_separation() -> int:
	var cards := _get_hand_cards()
	var count := cards.size()
	if count <= 1:
		return _base_separation

	var card_width := _get_card_width()
	var min_sep := -(card_width - MIN_VISIBLE_CARD_WIDTH)

	if count < SPACED_HAND_COUNT:
		return int(round(maxf(float(HAND_SLIGHT_OVERLAP_SEPARATION), min_sep)))

	if count == SPACED_HAND_COUNT:
		return _base_separation

	# Keep the packed row about as wide as a five-card hand.
	var target_width := SPACED_HAND_COUNT * card_width + (SPACED_HAND_COUNT - 1) * _base_separation
	var packed_sep := (target_width - count * card_width) / float(count - 1)
	return int(round(maxf(packed_sep, min_sep)))


func _get_card_width() -> float:
	for card in _get_hand_cards():
		var width := maxf(card.size.x, card.custom_minimum_size.x)
		if width > 1.0:
			return width
	return DEFAULT_CARD_WIDTH


func _get_hover_push_amount() -> float:
	var card_width := _get_card_width()
	var scale_extra := card_width * (CardUI.HAND_HOVER_SCALE - 1.0) * 0.5
	var overlap := maxf(0.0, -float(_compute_hand_separation()))
	return scale_extra + overlap + HOVER_PUSH_PADDING


func _apply_hover_spread(animate: bool) -> void:
	# A picked card owns the hand layout until placement ends. Do not collapse the fan mid-slide.
	if _placement_focus_card != null:
		return
	var cards := _get_hand_cards()
	# Typed Array.find() rejects null. Skip the lookup when nothing is featured.
	var featured_index := cards.find(_featured_card) if _featured_card != null else -1
	var push := _get_hover_push_amount() if featured_index >= 0 else 0.0
	# Selected placement cards stay lifted without pushing neighbors aside.
	if featured_index >= 0 and _should_keep_card_elevated(cards[featured_index]):
		push = 0.0
	for i in cards.size():
		var card := cards[i]
		if is_preserving_offset_for(card):
			continue
		var spread := _compute_card_spread_offset(i, featured_index, push)
		var spread_rotation := _compute_card_spread_rotation(i, featured_index)
		card.set_hand_spread_pose(spread, spread_rotation, animate)


func _compute_card_spread_offset(card_index: int, featured_index: int, max_push: float) -> float:
	if featured_index < 0 or is_zero_approx(max_push) or card_index == featured_index:
		return 0.0
	var distance := absi(card_index - featured_index)
	var direction := -1.0 if card_index < featured_index else 1.0
	var weight := 1.0 / pow(float(distance), HOVER_SPREAD_FALLOFF_POWER)
	return direction * max_push * weight


func _compute_card_spread_rotation(card_index: int, featured_index: int) -> float:
	if featured_index < 0 or card_index == featured_index:
		return 0.0
	var distance := absi(card_index - featured_index)
	var direction := -1.0 if card_index < featured_index else 1.0
	var weight := 1.0 / pow(float(distance), HOVER_SPREAD_FALLOFF_POWER)
	return deg_to_rad(direction * HOVER_SPREAD_MAX_ROTATION_DEG * weight)


func _on_card_played(card_ui: CardUI) -> void:
	cards_played += 1
	if card_ui == _placement_focus_card:
		_placement_focus_card = null
	# Successful plays free the card without card_drag_ended. Restore siblings when play can continue.
	if not _hand_hidden and _will_have_playable_hand_after_card_removed():
		_request_sibling_restore()
	await _check_auto_end_turn_after_card_removed()


func _on_card_sold(_card_ui: CardUI) -> void:
	await _check_auto_end_turn_after_card_removed()


## Ends the turn when fewer than three cards remain after a play or a sell.
func _check_auto_end_turn_after_card_removed() -> void:
	# Wait for the removed card's queue_free() before counting the hand.
	await get_tree().create_timer(0.1).timeout
	if _get_hand_card_count() < 3:
		EventBus.turn_ended.emit()
		AudioManager.play_end_turn_bell()


func _on_card_drag_started(card: CardUI) -> void:
	if _awaiting_intro or _hand_hidden:
		return
	if _placement_focus_card == card and _siblings_hidden_for_placement:
		return
	_sibling_restore_generation += 1
	_placement_focus_card = card
	_featured_card = card
	_siblings_hidden_for_placement = true
	# Invisible in the HBox slot so neighbors keep their X while sliding down.
	card.begin_board_placement()
	_animate_siblings_slide(card, true)


func _on_card_drag_ended(_unused = null) -> void:
	# card_drag_ended carries no card argument. Always clear the placement focus here.
	_placement_focus_card = null
	if _hand_hidden:
		return
	_request_sibling_restore()


func _request_sibling_restore() -> void:
	_sibling_restore_generation += 1
	var generation := _sibling_restore_generation
	call_deferred("_restore_siblings_if_needed", generation)


func _restore_siblings_if_needed(generation: int) -> void:
	if generation != _sibling_restore_generation:
		return
	if _placement_focus_card != null or _hand_hidden:
		return
	if not _siblings_hidden_for_placement:
		return
	_animate_siblings_slide(null, false)


## The played card is still in the hand when this runs, so look one card ahead.
func _will_have_playable_hand_after_card_removed() -> bool:
	return get_hand_card_count() - 1 >= 3


func _hide_hand() -> void:
	_reset_placement_sibling_slide_state()
	_hand_hidden = true
	_generated_reveal.interrupt()
	_animate_hand_slide(true)


func _show_hand() -> void:
	## Don't fight the run-start entrance if a turn signal fires early.
	if _awaiting_intro:
		return
	# New turn, so reparent index math starts from the full current hand.
	cards_played = 0
	_hand_hidden = false
	_siblings_hidden_for_placement = false
	_animate_hand_slide(false)
	if _hand_slide_tween != null and _hand_slide_tween.is_valid():
		await _hand_slide_tween.finished
	_generated_reveal.try_play_next()


## True while starting cards should stay parked below the viewport.
func is_awaiting_intro() -> bool:
	return _awaiting_intro


func is_hand_hidden() -> bool:
	return _hand_hidden


func get_card_rest_offset() -> Vector2:
	if _hand_hidden:
		return Vector2(0.0, _get_hand_slide_distance())
	return Vector2.ZERO


## True while this card's offset_transform is owned by intro, a hidden hand, or a generated reveal.
func is_preserving_offset_for(card_ui: CardUI) -> bool:
	if _awaiting_intro or _hand_hidden:
		return true
	if _placement_focus_card != null:
		return true
	return _generated_reveal != null and _generated_reveal.is_animating_card(card_ui)


## After fade/zoom, slide each starting card up from below with a light stagger.
func play_intro_entrance() -> void:
	## CardBaseState waits one frame then clears hover offset to ZERO — wait past that,
	# then re-park so the entrance tween has a real distance to travel.
	await get_tree().process_frame
	_snap_hand_offscreen()

	if _hand_slide_tween and _hand_slide_tween.is_valid():
		_hand_slide_tween.kill()
		_hand_slide_tween = null

	_hand_slide_tween = create_tween()
	_hand_slide_tween.set_parallel(true)

	var animated_cards := 0
	for child in get_children():
		if not child is CardUI:
			continue
		var card := child as CardUI
		card.offset_transform_enabled = true
		var step := _hand_slide_tween.tween_property(
			card,
			"offset_transform_position",
			Vector2.ZERO,
			HAND_SLIDE_DURATION
		)
		step.set_delay(animated_cards * INTRO_CARD_STAGGER)
		step.set_ease(Tween.EASE_OUT)
		step.set_trans(Tween.TRANS_QUART)
		animated_cards += 1

	## Intro offset is now owned by the tween; allow normal hover afterward.
	_awaiting_intro = false

	if animated_cards == 0:
		_hand_slide_tween.kill()
		_hand_slide_tween = null
		_restore_card_mouse_filters()
		_hand_hidden = false
		_generated_reveal.try_play_next()
		return

	await _hand_slide_tween.finished
	_hand_slide_tween = null
	_restore_card_mouse_filters()
	_hand_hidden = false
	_generated_reveal.try_play_next()
	if InputManager.is_using_gamepad():
		ensure_controller_focus()


func _snap_hand_offscreen() -> void:
	for child in get_children():
		if child is CardUI:
			_snap_card_offscreen(child as CardUI)


func _snap_card_offscreen(card: CardUI) -> void:
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.offset_transform_enabled = true
	card.offset_transform_position = Vector2(0, _get_hand_slide_distance())


func _restore_card_mouse_filters() -> void:
	for child in get_children():
		if not child is CardUI:
			continue
		if _generated_reveal != null and _generated_reveal.is_animating_card(child as CardUI):
			continue
		var card := child as CardUI
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.hover_enabled = true


func _reset_placement_sibling_slide_state() -> void:
	_kill_sibling_slide_tween()
	_sibling_restore_generation += 1
	_placement_focus_card = null
	_siblings_hidden_for_placement = false


func _kill_sibling_slide_tween() -> void:
	if _sibling_slide_tween != null and _sibling_slide_tween.is_valid():
		_sibling_slide_tween.kill()
	_sibling_slide_tween = null


func _animate_siblings_slide(exclude_card: CardUI, should_hide: bool) -> void:
	_kill_sibling_slide_tween()

	if should_hide:
		_siblings_hidden_for_placement = true
	else:
		_siblings_hidden_for_placement = false
		_featured_card = null
		_spread_clear_pending = false

	var target_y := _get_hand_slide_distance() if should_hide else 0.0
	var hidden_siblings: Array[CardUI] = []
	_sibling_slide_tween = create_tween()
	_sibling_slide_tween.set_parallel(true)

	var animated_cards := 0
	for child in get_children():
		if not child is CardUI:
			continue
		var card := child as CardUI
		if card == exclude_card:
			continue
		if _generated_reveal != null and _generated_reveal.is_animating_card(card):
			continue
		animated_cards += 1
		hidden_siblings.append(card)
		if should_hide:
			_tween_sibling_offscreen(card, target_y)
		else:
			_tween_sibling_to_rest(card)

	if animated_cards == 0:
		_sibling_slide_tween.kill()
		_sibling_slide_tween = null
		if should_hide:
			_siblings_hidden_for_placement = false
		return

	if should_hide:
		_sibling_slide_tween.finished.connect(func() -> void:
			for card in hidden_siblings:
				if is_instance_valid(card):
					card.clear_hand_spread_state()
		)
	else:
		_sibling_slide_tween.finished.connect(func() -> void:
			_restore_sibling_mouse_filters(exclude_card)
		)


func _tween_sibling_offscreen(card: CardUI, target_y: float) -> void:
	card.prepare_hand_slot_slide()
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var start_pos := card.offset_transform_position
	# Keep the current X. Only Y leaves the screen.
	var step := _sibling_slide_tween.tween_method(
		func(y_pos: float) -> void:
			card.offset_transform_position = Vector2(start_pos.x, y_pos),
		start_pos.y,
		target_y,
		HAND_SLIDE_DURATION
	)
	step.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUART)


func _tween_sibling_to_rest(card: CardUI) -> void:
	card.prepare_hand_slot_rest()
	_tween_card_offset(card, "offset_transform_position", Vector2.ZERO)
	_tween_card_offset(card, "offset_transform_rotation", 0.0)
	_tween_card_offset(card, "offset_transform_scale", Vector2.ONE)


func _tween_card_offset(card: CardUI, property: String, target: Variant) -> void:
	_sibling_slide_tween.tween_property(card, property, target, HAND_SLIDE_DURATION).set_ease(
		Tween.EASE_OUT
	).set_trans(Tween.TRANS_QUART)


func _restore_sibling_mouse_filters(exclude_card: CardUI) -> void:
	for child in get_children():
		if not child is CardUI:
			continue
		var card := child as CardUI
		if card == exclude_card:
			continue
		if _generated_reveal != null and _generated_reveal.is_animating_card(card):
			continue
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.hover_enabled = true


func _animate_hand_slide(should_hide: bool) -> void:
	_kill_sibling_slide_tween()
	if _hand_slide_tween and _hand_slide_tween.is_valid():
		_hand_slide_tween.kill()
		_hand_slide_tween = null

	var slide_distance := _get_hand_slide_distance()
	var target_y := slide_distance if should_hide else 0.0

	_hand_slide_tween = create_tween()
	_hand_slide_tween.set_parallel(true)

	var animated_cards := 0
	for child in get_children():
		if not child is CardUI:
			continue
		var card := child as CardUI
		# The reveal owns this card's offset until it settles into the hand.
		if _generated_reveal != null and _generated_reveal.is_animating_card(card):
			continue
		animated_cards += 1

		if should_hide:
			# Drop hover lift so the slide starts from the layout slot, not an elevated pose.
			card.set_hover_elevated(false, false)
			# offset_transform is visual-only by default. Block clicks while off-screen.
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		card.offset_transform_enabled = true
		var step := _hand_slide_tween.tween_property(
			card,
			"offset_transform_position",
			Vector2(card.get_hand_spread_x(), target_y),
			HAND_SLIDE_DURATION
		)
		step.set_ease(Tween.EASE_IN if should_hide else Tween.EASE_OUT)
		step.set_trans(Tween.TRANS_QUART)

	if animated_cards == 0:
		_hand_slide_tween.kill()
		_hand_slide_tween = null
		return

	if not should_hide:
		_hand_slide_tween.finished.connect(func() -> void:
			_restore_card_mouse_filters()
		)


func _get_hand_slide_distance() -> float:
	# Full viewport height guarantees cards leave the screen from the bottom edge.
	return get_viewport().get_visible_rect().size.y


func capture_hand_state() -> Dictionary:
	var cards: Array = []
	for child in get_children():
		if not child is CardUI:
			continue
		var card_ui := child as CardUI
		if card_ui.card == null:
			continue
		cards.append({"kind": card_ui.card.get_save_kind(), "id": card_ui.card.id})

	return {
		"cards": cards,
		"cards_played": cards_played,
		"pending_generated_cards": _generated_reveal.capture_pending(),
	}


func restore_hand_state(state: Dictionary) -> void:
	# Park restored cards off-screen, main.gd replays the hand intro afterward.
	_awaiting_intro = true
	_hand_hidden = true

	for child in get_children():
		if child is CardUI:
			remove_child(child)
			child.free()

	cards_played = int(state.get("cards_played", 0))
	var saved_count := 0
	var restored_count := 0
	for entry: Dictionary in state.get("cards", []):
		saved_count += 1
		var kind: String = entry.get("kind", "")
		var card_id: String = entry.get("id", "")
		if kind == "tile_card":
			var tile_card := GameManager.get_tile_card_by_id(card_id)
			if tile_card != null:
				_add_tile_card(tile_card)
				restored_count += 1

	if restored_count < saved_count:
		push_warning(
			"Hand restore dropped %d/%d cards. Missing ids are not in the pool."
			% [saved_count - restored_count, saved_count]
		)

	_generated_reveal.restore_pending(state.get("pending_generated_cards", []))
