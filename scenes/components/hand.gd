class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
## Slide the hand off-screen between turns. Only the visual pose moves, so layout is untouched.
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
## Card the mouse rests on. Resolved here from the drawn cards, not from each card's layout slot.
var _hovered_card: CardUI = null
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


func _process(delta: float) -> void:
	_update_mouse_hover()
	_update_hover_lean(delta)


func _input(event: InputEvent) -> void:
	if not event.is_action_pressed("left_mouse"):
		return
	# The cursor may have moved since the last frame.
	_update_mouse_hover()
	if _hovered_card == null:
		return
	# A lifted card reaches past its layout slot and over its neighbors' slots.
	# Take the press here so the card under the cursor is the one that gets grabbed.
	_hovered_card.begin_press()
	get_viewport().set_input_as_handled()


## Deal the opening hand after run RNG has been seeded and setup rolls have finished.
func build_starting_hand() -> void:
	if RunSaveManager.should_restore_run():
		return

	var specialty := GameManager.selected_specialty
	if specialty == null:
		return

	var stream_name := "starting_hand:%s:%d" % [
		specialty.id,
		int(GameManager.selected_difficulty),
	]
	RunRng.using_fresh_stream(stream_name, func() -> void:
		var starting_cards := SpecialtyRegistry.get_starting_hand_cards(specialty)
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
	var new_card := CARD_UI_SCENE.instantiate() as CardUI
	new_card.configure_interaction(CardUI.InteractionMode.HAND)
	add_child(new_card)
	new_card.set_card(data)
	# Cards dealt during intro or while the hand is slid away stay below the viewport.
	if _awaiting_intro or _hand_hidden:
		_snap_card_offscreen(new_card)
	call_deferred("_refresh_hand_layout")
	return new_card


## Guard against non-card children
func get_hand_card_count() -> int:
	return _get_hand_cards().size()


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


#region Mouse hover

## True while the cursor rests on a hand card, including the part lifted above its slot.
func is_mouse_on_card() -> bool:
	return is_instance_valid(_hovered_card)


func _update_mouse_hover() -> void:
	if not is_instance_valid(_hovered_card):
		_hovered_card = null
	if InputManager.is_using_gamepad():
		# Controller focus owns the lift. Only drop the mouse card's tooltips.
		if _hovered_card != null:
			_hovered_card.set_hand_hovered(false, false)
			_hovered_card = null
		return
	_set_hovered_card(_pick_hovered_card(get_global_mouse_position()))


## force re-applies hover to a card that is already current, such as one returning from a drag.
func _set_hovered_card(card: CardUI, force: bool = false) -> void:
	var previous := _hovered_card
	if card == previous and not force:
		return
	_hovered_card = card
	if previous != null and previous != card:
		previous.set_hand_hovered(false)
	if card != null:
		card.set_hand_hovered(true)
		if card != previous:
			AudioManager.play_ui_hover()


func _pick_hovered_card(mouse: Vector2) -> CardUI:
	if _awaiting_intro or _hand_hidden or _placement_focus_card != null:
		return null
	# A held press keeps its card even if the pointer slips off before the drag starts.
	if _hovered_card != null and _hovered_card.is_press_held():
		return _hovered_card
	if _is_mouse_blocked():
		return null
	# The lifted card keeps hover across everything it draws over, so crossing it never flickers.
	if _hovered_card != null \
			and _can_hover(_hovered_card) \
			and _hovered_card.get_hover_hit_rect().has_point(mouse):
		return _hovered_card
	# Later cards draw on top where slots overlap.
	var cards := _get_hand_cards()
	for i in range(cards.size() - 1, -1, -1):
		if _can_hover(cards[i]) and cards[i].get_hover_hit_rect().has_point(mouse):
			return cards[i]
	return null


func _can_hover(card: CardUI) -> bool:
	return (
		card.hover_enabled
		and card.mouse_filter != Control.MOUSE_FILTER_IGNORE
		and not card.is_held_for_placement()
		and not card.is_queued_for_deletion()
	)


## True when another control sits between the cursor and the hand, such as an open panel.
func _is_mouse_blocked() -> bool:
	var hovered := get_viewport().gui_get_hovered_control()
	if hovered == null:
		return false
	var root := get_parent()
	return hovered != root and not root.is_ancestor_of(hovered)


## The hovered card leans toward the cursor. Every other card eases back upright.
func _update_hover_lean(delta: float) -> void:
	var mouse_x := get_global_mouse_position().x
	for card in _get_hand_cards():
		var lean := 0.0
		if card == _hovered_card:
			var slot := card.get_global_rect()
			lean = (mouse_x - slot.get_center().x) / maxf(slot.size.x * 0.5, 1.0)
		card.update_hover_lean(lean, delta)

#endregion


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
		card.set_hover_elevated(false, true)
	# Close the fan now that nothing is focused.
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
		card.set_hover_elevated(card == focused, true)


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
	# Off-screen cards have no fan. A picked card owns the layout until its placement ends.
	if _awaiting_intro or _hand_hidden or _placement_focus_card != null:
		return
	var cards := _get_hand_cards()
	# Typed Array.find() rejects null. Skip the lookup when nothing is featured.
	var featured_index := cards.find(_featured_card) if _featured_card != null else -1
	var push := _get_hover_push_amount() if featured_index >= 0 else 0.0
	for i in cards.size():
		var card := cards[i]
		# The showcase should not shift while another card is hovered.
		if _is_reveal_card(card):
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


func _on_card_played(_card_ui: CardUI) -> void:
	cards_played += 1
	await _check_auto_end_turn_after_card_removed()


func _on_card_sold(_card_ui: CardUI) -> void:
	await _check_auto_end_turn_after_card_removed()


## Ends the turn when fewer than three cards remain after a play or a sell.
func _check_auto_end_turn_after_card_removed() -> void:
	# Wait for the removed card's queue_free() before counting the hand.
	await get_tree().create_timer(0.1).timeout
	if get_hand_card_count() < 3:
		EventBus.turn_ended.emit()
		AudioManager.play_end_turn_bell()


func _on_card_drag_started(card: CardUI) -> void:
	if _awaiting_intro or _hand_hidden:
		return
	_sibling_restore_generation += 1
	_placement_focus_card = card
	_featured_card = card
	# Hidden in its HBox slot so neighbors keep their X while they slide down.
	card.begin_board_placement()
	_animate_siblings_slide(card, true)


func _on_card_drag_ended(card: CardUI, outcome: int) -> void:
	_placement_focus_card = null
	var cancelled := outcome == CardPlacementHandler.DragOutcome.CANCELLED
	if cancelled:
		card.end_board_placement(not _hand_hidden)
		if not _hand_hidden:
			# The card kept its lifted pose while hidden. Settle it unless the cursor is still on it.
			_hovered_card = card
			var still_hovered: CardUI = null
			if not InputManager.is_using_gamepad():
				still_hovered = _pick_hovered_card(get_global_mouse_position())
			_set_hovered_card(still_hovered, true)
	elif _featured_card == card:
		_featured_card = null
	if _hand_hidden:
		return
	# A played or sold card is still in the hand here. Keep the rest away when the turn is about to end.
	if not cancelled and not _will_have_playable_hand_after_card_removed():
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


## The removed card is still in the hand when this runs, so look one card ahead.
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
	# cards_played only counts plays in the current turn.
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


## After fade/zoom, slide each starting card up from below with a light stagger.
func play_intro_entrance() -> void:
	_snap_hand_offscreen()
	_kill_hand_slide_tween()

	## Cards rise from here on, so stop parking new ones below the screen.
	_awaiting_intro = false

	var cards := _get_hand_cards()
	if not cards.is_empty():
		_hand_slide_tween = create_tween().set_parallel(true)
		_hand_slide_tween.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUART)
		for i in cards.size():
			_hand_slide_tween.tween_property(
				cards[i], "slot_offset", Vector2.ZERO, HAND_SLIDE_DURATION
			).set_delay(i * INTRO_CARD_STAGGER)
		await _hand_slide_tween.finished
		_hand_slide_tween = null

	_hand_hidden = false
	_restore_card_interaction()
	_generated_reveal.try_play_next()
	if InputManager.is_using_gamepad():
		ensure_controller_focus()


func _snap_hand_offscreen() -> void:
	for card in _get_hand_cards():
		_snap_card_offscreen(card)


func _snap_card_offscreen(card: CardUI) -> void:
	# The pose is visual only, so block clicks while the card is parked below the screen.
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.slot_offset = Vector2(0.0, _get_hand_slide_distance())


## Makes settled cards clickable again. Hover picks them up on the next frame.
func _restore_card_interaction() -> void:
	for card in _get_hand_cards():
		if _is_reveal_card(card) or card.is_held_for_placement():
			continue
		card.mouse_filter = Control.MOUSE_FILTER_STOP
		card.hover_enabled = true


## The reveal owns this card's slot offset until it settles into the hand.
func _is_reveal_card(card: CardUI) -> bool:
	return _generated_reveal != null and _generated_reveal.is_animating_card(card)


func _reset_placement_sibling_slide_state() -> void:
	_kill_sibling_slide_tween()
	_sibling_restore_generation += 1
	_placement_focus_card = null
	_siblings_hidden_for_placement = false


func _kill_sibling_slide_tween() -> void:
	if _sibling_slide_tween != null and _sibling_slide_tween.is_valid():
		_sibling_slide_tween.kill()
	_sibling_slide_tween = null


func _kill_hand_slide_tween() -> void:
	if _hand_slide_tween != null and _hand_slide_tween.is_valid():
		_hand_slide_tween.kill()
	_hand_slide_tween = null


## Slides every card except exclude_card below the screen, or brings the whole hand back up.
func _animate_siblings_slide(exclude_card: CardUI, should_hide: bool) -> void:
	_kill_sibling_slide_tween()
	_siblings_hidden_for_placement = should_hide

	var siblings: Array[CardUI] = []
	for card in _get_hand_cards():
		if card != exclude_card and not _is_reveal_card(card):
			siblings.append(card)
	if siblings.is_empty():
		_siblings_hidden_for_placement = false
		return

	var target_y := _get_hand_slide_distance() if should_hide else 0.0
	_sibling_slide_tween = create_tween().set_parallel(true)
	_sibling_slide_tween.set_trans(Tween.TRANS_QUART)
	_sibling_slide_tween.set_ease(Tween.EASE_IN if should_hide else Tween.EASE_OUT)
	for card in siblings:
		if should_hide:
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Only the slot layer moves. Fan spread keeps each card's X on the way down.
		_sibling_slide_tween.tween_property(card, "slot_offset:y", target_y, HAND_SLIDE_DURATION)

	if should_hide:
		_sibling_slide_tween.finished.connect(func() -> void:
			for card in siblings:
				if is_instance_valid(card):
					card.reset_hand_pose()
		)
	else:
		# Fan around the returning card again if it is still under the cursor.
		_apply_hover_spread(true)
		_sibling_slide_tween.finished.connect(_restore_card_interaction)


func _animate_hand_slide(should_hide: bool) -> void:
	_kill_sibling_slide_tween()
	_kill_hand_slide_tween()
	_featured_card = null
	_spread_clear_pending = false

	var cards: Array[CardUI] = []
	for card in _get_hand_cards():
		if not _is_reveal_card(card):
			cards.append(card)
	if cards.is_empty():
		return

	var target_y := _get_hand_slide_distance() if should_hide else 0.0
	_hand_slide_tween = create_tween().set_parallel(true)
	_hand_slide_tween.set_trans(Tween.TRANS_QUART)
	_hand_slide_tween.set_ease(Tween.EASE_IN if should_hide else Tween.EASE_OUT)
	for card in cards:
		if should_hide:
			# The pose is visual only. Block clicks while the card is off-screen.
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Hover lift and fan spread settle on their own layer while the slot slides.
		card.reset_hand_pose(should_hide)
		_hand_slide_tween.tween_property(
			card, "slot_offset", Vector2(0.0, target_y), HAND_SLIDE_DURATION
		)

	if not should_hide:
		_hand_slide_tween.finished.connect(_restore_card_interaction)


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
