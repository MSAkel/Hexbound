class_name Hand
extends HBoxContainer

## The hand on screen. DeckManager owns the cards: this shows what it draws and frees the cards
## it discards. Plays go back to DeckManager, which ends the Hour after its plays are used up.

## Plays this Hour (DeckManager.plays_this_hour).
var cards_played: int:
	get:
		return DeckManager.plays_this_hour

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
## Slide the hand off-screen between turns. Only the visual pose moves, so layout is untouched.
const HAND_SLIDE_DURATION := 0.35
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

## Drawn cards fly out of the deck pile and arc into their slots, tilted at a fixed angle.
const DEAL_DURATION := 0.55
## Delay between one drawn card leaving the pile and the next.
const DEAL_STAGGER := 0.1
## Tilt a drawn card holds in flight, in degrees. It straightens out over DEAL_SETTLE as it lands.
const DEAL_TILT_DEG := -14.0
## Share of the flight at the end spent straightening.
const DEAL_SETTLE := 0.2
## How far the flight path bows up above a straight line, in pixels.
const DEAL_ARC_HEIGHT := 160.0
## Drawn cards leave the pile at this size and grow to full size in the hand.
const DEAL_START_SCALE := 0.55
## Share of the flight spent fading in from the pile.
const DEAL_FADE_IN := 0.2

## Longest the deal waits for a picked card to land on the pile.
const PICK_FLIGHT_WAIT_CAP := 1.5

## Discarded cards fling into the chef portrait. Short and fast.
const DISCARD_DURATION := 0.26
const DISCARD_STAGGER := 0.04
## Tilt a discarded card takes on over the first DISCARD_TILT_IN of its flight and then holds.
const DISCARD_TILT_DEG := -18.0
const DISCARD_TILT_IN := 0.2
const DISCARD_ARC_HEIGHT := 70.0
const DISCARD_END_SCALE := 0.25
## Share of the flight at the end spent fading out.
const DISCARD_FADE_OUT := 0.35
## Share of the flight at the start spent fading in, for cards that were slid below the screen.
const DISCARD_FADE_IN := 0.25

## Flights tilt cards around their middle. At rest the hand pivots them on the bottom edge.
const FLIGHT_PIVOT := Vector2(0.5, 0.5)
const REST_PIVOT := Vector2(0.5, 1.0)

## Debug-only cards added to the opening hand.
@export_group("Debug Starting Hand")
@export var debug_starting_runes: Array[TileCard] = []

@onready var _generated_reveal: GeneratedCardReveal = $"../GeneratedCardReveal"

## Keep starting cards parked off-screen until Main finishes fade/zoom.
var _awaiting_intro := true
## True while the hand is slid below the viewport (intro or turn resolution).
var _hand_hidden := true
## True while a hidden hand is slid up for a look from a between-turn panel. Cards stay unplayable.
var _peeking := false
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
## Slot to return to when controller focus comes back, such as after a pick-up is cancelled.
var _last_controller_focus_index := 0
## Hand card currently selected for map placement.
var _placement_focus_card: CardUI = null
## True while non-selected siblings are slid off-screen for placement.
var _siblings_hidden_for_placement := false
var _sibling_slide_tween: Tween = null
## Bumped to drop stale deferred sibling restores after a new drag starts.
var _sibling_restore_generation := 0
## Cards on screen when DeckManager discarded the hand. They go once the hand has slid away.
var _discarded_cards: Array[CardUI] = []
var _discard_pending: bool:
	get:
		return not _discarded_cards.is_empty()
var _discard_tween: Tween = null
## Drawn cards waiting to fly in from the deck pile or still on the way. The hand slide and
## interaction restore leave them alone until they land.
var _deal_queue: Array[CardUI] = []
var _deal_tween: Tween = null

func _ready() -> void:
	_base_separation = get_theme_constant("separation")
	EventBus.card_played.connect(_on_card_played)
	DeckManager.cards_drawn.connect(_on_cards_drawn)
	DeckManager.hand_discarded.connect(_on_hand_discarded)
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


## Build the starting deck and draw the first hand, after run RNG has been seeded.
func build_starting_hand() -> void:
	if RunSaveManager.should_restore_run():
		return

	var chef := GameManager.selected_chef
	if chef == null:
		return

	var stream_name := "starting_deck:%s" % chef.id
	RunRng.using_fresh_stream(stream_name, func() -> void:
		var deck := ChefRegistry.build_starting_deck(chef)
		var cards: Array[TileCard] = []
		cards.assign(deck["cards"])
		var stations: Array[String] = []
		stations.assign(deck["stations"])
		DeckManager.start_run(cards, stations)

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
			DeckManager.gain_card(rune, DeckManager.Source.DEBUG)


func _on_cards_drawn(cards: Array[TileCard]) -> void:
	# A new hand replaces whatever the last Hour left on screen. A mid-Hour discard is still flying
	# to the chef portrait and frees itself when it lands.
	if not DeckManager.is_redrawing:
		_free_discarded_cards()
	var added: Array[CardUI] = []
	for card: TileCard in cards:
		added.append(_add_card(card))
	# The run-start entrance deals the opening hand itself.
	if _awaiting_intro or GameManager.skip_presentation:
		return
	if _hand_hidden:
		# Dealt when the hand comes back up for the Hour.
		_deal_queue.append_array(added)
		return
	_deal_cards(added)


## The generated-card reveal adds its card here once it lands.
func create_hand_card(data: Card) -> CardUI:
	if data is TileCard and not DeckManager.hand.has(data as TileCard):
		DeckManager.hand.append(data as TileCard)
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
## Saving here would persist a finished hand with no draft and no resolve.
func has_pending_auto_end() -> bool:
	return DeckManager.plays_this_hour > 0 and DeckManager.is_hour_finished()


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
	var previous := _controller_focus_index
	if _controller_focus_index < 0:
		_controller_focus_index = 0 if direction >= 0 else cards.size() - 1
	else:
		_controller_focus_index = clampi(_controller_focus_index + direction, 0, cards.size() - 1)
	if _controller_focus_index != previous:
		AudioManager.play_ui_hover()
	_apply_controller_focus_visual()


func ensure_controller_focus() -> void:
	var cards := _get_hand_cards()
	if cards.is_empty():
		_controller_focus_index = -1
		_apply_controller_focus_visual()
		return
	if _controller_focus_index < 0 or _controller_focus_index >= cards.size():
		_controller_focus_index = clampi(_last_controller_focus_index, 0, cards.size() - 1)
	_apply_controller_focus_visual()


func clear_controller_focus() -> void:
	if _controller_focus_index >= 0:
		_last_controller_focus_index = _controller_focus_index
	_controller_focus_index = -1
	for card in _get_hand_cards():
		card.set_hand_hovered(false)
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
	# Lift and keyword tips follow the focus ring, the same as a mouse hover.
	for card in _get_hand_cards():
		if card != focused:
			card.set_hand_hovered(false)
	if focused != null:
		focused.set_hand_hovered(true)


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


func _on_card_played(card_ui: CardUI) -> void:
	if card_ui != null and card_ui.card is TileCard:
		DeckManager.play(card_ui.card as TileCard)
	await _check_auto_end_turn_after_card_removed()


## Ends the Hour once its plays are used up or the hand is empty.
func _check_auto_end_turn_after_card_removed() -> void:
	# Let the played card's queue_free() and landing settle first.
	await get_tree().create_timer(0.1).timeout
	if DeckManager.is_hour_finished() and not GameManager.is_processing_turn:
		end_hour()


## The End Hour button and the last play of an Hour both land here.
func end_hour() -> void:
	if GameManager.is_processing_turn or RoundFlow.is_transitioning() or _hand_hidden:
		return
	EventBus.turn_ended.emit()
	AudioManager.play_end_turn_bell()


## Discard button: throws the hand away and draws as many new cards (DeckManager.discard_hand).
func discard_hand() -> void:
	if not can_discard_hand():
		return
	DeckManager.discard_hand()


## True while the hand is up, nothing is resolving and a discard is left this Day.
func can_discard_hand() -> bool:
	return can_end_hour() and _discarded_cards.is_empty() and _deal_queue.is_empty() and DeckManager.can_discard_hand()


## True while the player can end the Hour: the hand is up and nothing is resolving.
func can_end_hour() -> bool:
	return (
		not _awaiting_intro
		and not _hand_hidden
		and not GameManager.is_processing_turn
		and not RoundFlow.is_transitioning()
		and _placement_focus_card == null
	)


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


## DeckManager already counted the play when this runs.
func _will_have_playable_hand_after_card_removed() -> bool:
	return not DeckManager.is_hour_finished()


func _hide_hand() -> void:
	_reset_placement_sibling_slide_state()
	_hand_hidden = true
	_peeking = false
	_generated_reveal.interrupt()
	_cancel_deal()
	# Discarded cards fly to the chef portrait instead of sliding down with the rest.
	_animate_hand_slide(true)
	if _discard_pending:
		_fling_discarded_cards()


func _on_hand_discarded() -> void:
	_discarded_cards.append_array(_get_hand_cards())
	# The Discard button: the hand stays up, so the old cards fly off now. A deal still running would
	# keep posing them (and error once they are freed), so it stops first.
	if DeckManager.is_redrawing:
		_cancel_deal()
		_fling_discarded_cards()


## Frees the cards the last Hour discarded. They are already gone from DeckManager.hand.
func _free_discarded_cards() -> void:
	if _discard_tween != null and _discard_tween.is_valid():
		_discard_tween.kill()
	_discard_tween = null
	var cards := _discarded_cards.duplicate()
	_discarded_cards.clear()
	for card: CardUI in cards:
		if is_instance_valid(card) and card.get_parent() == self:
			remove_child(card)
			card.queue_free()


func _show_hand() -> void:
	## Don't fight the run-start entrance if a turn signal fires early.
	if _awaiting_intro:
		return
	_hand_hidden = false
	_peeking = false
	_siblings_hidden_for_placement = false
	_animate_hand_slide(false)
	var slide := _hand_slide_tween
	if not _deal_queue.is_empty():
		await _deal_cards(_deal_queue.duplicate())
	await TweenWait.finished(self, slide)
	_generated_reveal.try_play_next()


## True while starting cards should stay parked below the viewport.
func is_awaiting_intro() -> bool:
	return _awaiting_intro


func is_hand_hidden() -> bool:
	return _hand_hidden


## Slides the hidden hand up so card pick and merchant board views can show it.
## View only: the hand still counts as hidden, so cards can't be hovered, dragged or played.
func set_peek(active: bool) -> void:
	if _awaiting_intro or not _hand_hidden or _peeking == active:
		return
	_peeking = active
	_animate_hand_slide(not active, false)


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

	var cards: Array[CardUI] = []
	for card in _get_hand_cards():
		if not _is_reveal_card(card):
			cards.append(card)
	if not cards.is_empty():
		# The opening hand is drawn from the deck pile like every other Hour.
		await _deal_cards(cards)

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
		if _is_reveal_card(card) or card.is_held_for_placement() or _deal_queue.has(card):
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


func _animate_hand_slide(should_hide: bool, restore_interaction: bool = true) -> void:
	_kill_sibling_slide_tween()
	_kill_hand_slide_tween()
	_featured_card = null
	_spread_clear_pending = false

	var cards: Array[CardUI] = []
	for card in _get_hand_cards():
		if not _is_reveal_card(card) and not _deal_queue.has(card) and not _discarded_cards.has(card):
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

	if not should_hide and restore_interaction:
		_hand_slide_tween.finished.connect(_restore_card_interaction)


func _get_hand_slide_distance() -> float:
	# Full viewport height guarantees cards leave the screen from the bottom edge.
	return get_viewport().get_visible_rect().size.y


#region Deal and discard flights

## Flies cards from the deck pile into their hand slots on a tilted arc. Returns once they land.
func _deal_cards(cards: Array[CardUI]) -> void:
	for card in cards:
		if not _deal_queue.has(card):
			_deal_queue.append(card)
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.modulate.a = 0.0
	# New cards only get their slots once the container lays them out.
	await get_tree().process_frame
	# A picked card flying into the pile lands first, so it is visibly dealt from the top.
	var waited := 0.0
	while is_inside_tree() and waited < PICK_FLIGHT_WAIT_CAP 			and get_tree().get_first_node_in_group(CardSelectionUI.PICK_FLIGHT_GROUP) != null:
		await get_tree().process_frame
		waited += get_process_delta_time()
	if not is_inside_tree():
		return
	var landing: Array[CardUI] = []
	for card in cards:
		if is_instance_valid(card) and card.get_parent() == self and _deal_queue.has(card):
			landing.append(card)
	if landing.is_empty():
		return
	if GameManager.skip_presentation:
		for card in landing:
			_land_dealt_card(card, true)
		return

	var from := _deal_origin()
	var speed := GameManager.game_speed
	var duration := DEAL_DURATION / speed
	var tween := create_tween().set_parallel(true)
	_deal_tween = tween
	for i in landing.size():
		var card := landing[i]
		card.reset_hand_pose()
		card.offset_transform_pivot_ratio = FLIGHT_PIVOT
		var start := from - card.get_global_rect().get_center()
		_set_deal_pose(0.0, card, start)
		var delay := i * DEAL_STAGGER / speed
		tween.tween_method(_set_deal_pose.bind(card, start), 0.0, 1.0, duration).set_delay(delay) \
			.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		tween.tween_property(card, "modulate:a", 1.0, duration * DEAL_FADE_IN).set_delay(delay)
		tween.tween_callback(_land_dealt_card.bind(card, false)).set_delay(delay + duration)
	await TweenWait.finished(self, tween)


func _set_deal_pose(t: float, card: CardUI, start: Vector2) -> void:
	if not is_instance_valid(card):
		return
	var arc := Vector2(0.0, -DEAL_ARC_HEIGHT * 4.0 * t * (1.0 - t))
	card.slot_offset = start.lerp(Vector2.ZERO, t) + arc
	card.slot_rotation = deg_to_rad(DEAL_TILT_DEG) * (1.0 - smoothstep(1.0 - DEAL_SETTLE, 1.0, t))
	card.slot_scale = Vector2.ONE * lerpf(DEAL_START_SCALE, 1.0, t)


## Settles a dealt card in its slot. It becomes playable once the hand is up.
func _land_dealt_card(card: CardUI, snap: bool) -> void:
	_deal_queue.erase(card)
	if not is_instance_valid(card):
		return
	_clear_flight_pose(card)
	if snap:
		card.slot_offset = Vector2.ZERO
	if not _hand_hidden and not _awaiting_intro:
		_restore_card_interaction()


## Drops any deal in progress. Cards keep their slot offset so the hand slide can take over.
func _cancel_deal() -> void:
	if _deal_tween != null and _deal_tween.is_valid():
		_deal_tween.kill()
	_deal_tween = null
	for card in _deal_queue:
		if is_instance_valid(card):
			_clear_flight_pose(card)
	_deal_queue.clear()


func _clear_flight_pose(card: CardUI) -> void:
	card.slot_rotation = 0.0
	card.slot_scale = Vector2.ONE
	card.modulate.a = 1.0
	card.offset_transform_pivot_ratio = REST_PIVOT


## Centre of the deck pile, or the bottom-right corner when the pile is not on screen.
func _deal_origin() -> Vector2:
	var hud := get_tree().get_first_node_in_group("deck_hud") as DeckHud
	if hud != null and hud.is_visible_in_tree():
		return hud.get_pile_rect().get_center()
	return get_viewport().get_visible_rect().size


## Flings the discarded cards into the chef portrait, then frees them.
func _fling_discarded_cards() -> void:
	var cards: Array[CardUI] = []
	for card in _discarded_cards:
		if is_instance_valid(card) and card.get_parent() == self:
			cards.append(card)
	if cards.is_empty() or GameManager.skip_presentation:
		_free_discarded_cards()
		return

	var target := _discard_target()
	var speed := GameManager.game_speed
	var duration := DISCARD_DURATION / speed
	if _discard_tween != null and _discard_tween.is_valid():
		_discard_tween.kill()
	_discard_tween = create_tween().set_parallel(true)
	for i in cards.size():
		var card := cards[i]
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.reset_hand_pose()
		card.offset_transform_pivot_ratio = FLIGHT_PIVOT
		# Placing a card slides the rest of the hand below the screen, and the last play of an Hour
		# leaves them there. Those start from their slot instead, fading in so they don't pop.
		var start := card.slot_offset
		var delay := i * DISCARD_STAGGER / speed
		if start.y > 0.0:
			start.y = 0.0
			card.modulate.a = 0.0
			_discard_tween.tween_property(card, "modulate:a", 1.0, duration * DISCARD_FADE_IN).set_delay(delay)
		var end := target - card.get_global_rect().get_center()
		_discard_tween.tween_method(_set_discard_pose.bind(card, start, end), 0.0, 1.0, duration) \
			.set_delay(delay).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		_discard_tween.tween_property(card, "modulate:a", 0.0, duration * DISCARD_FADE_OUT) \
			.set_delay(delay + duration * (1.0 - DISCARD_FADE_OUT))
	_discard_tween.finished.connect(_free_discarded_cards)


func _set_discard_pose(t: float, card: CardUI, start: Vector2, end: Vector2) -> void:
	if not is_instance_valid(card):
		return
	var arc := Vector2(0.0, -DISCARD_ARC_HEIGHT * 4.0 * t * (1.0 - t))
	card.slot_offset = start.lerp(end, t) + arc
	card.slot_rotation = deg_to_rad(DISCARD_TILT_DEG) * smoothstep(0.0, DISCARD_TILT_IN, t)
	card.slot_scale = Vector2.ONE * lerpf(1.0, DISCARD_END_SCALE, t)


## Centre of the chef portrait, or the bottom-left corner when it is not on screen.
func _discard_target() -> Vector2:
	var panel := get_tree().get_first_node_in_group("card_sell_panel") as CardSellPanel
	if panel != null and panel.is_visible_in_tree():
		return panel.get_portrait_rect().get_center()
	return Vector2(0.0, get_viewport().get_visible_rect().size.y)

#endregion


func capture_hand_state() -> Dictionary:
	# The cards themselves are saved by DeckManager.
	return {
		"pending_generated_cards": _generated_reveal.capture_pending(),
	}


func restore_hand_state(state: Dictionary) -> void:
	# Park restored cards off-screen, main.gd replays the hand intro afterward.
	_awaiting_intro = true
	_hand_hidden = true
	_cancel_deal()
	_free_discarded_cards()

	for child in get_children():
		if child is CardUI:
			remove_child(child)
			child.free()

	for card: TileCard in DeckManager.hand:
		_add_card(card)

	_generated_reveal.restore_pending(state.get("pending_generated_cards", []))
