class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
## Slide the hand off-screen between turns using 4.7 offset transforms (layout-safe).
const HAND_SLIDE_DURATION := 0.35
## Stagger between each card during the run-start entrance from below.
const INTRO_CARD_STAGGER := 0.07
## Hands of this size and smaller keep full spacing. Larger hands start to overlap.
const SPACED_HAND_COUNT := 5
## Never overlap so far that a card is left with a sliver too small to click.
const MIN_VISIBLE_CARD_WIDTH := 56.0
## Extra gap opened around a featured card so the 1.2 hover scale does not cover neighbors.
const HOVER_PUSH_PADDING := 10.0
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

## Reparent cards to hand when they are dragged or released
func _ready() -> void:
	_base_separation = get_theme_constant("separation")
	EventBus.card_played.connect(_on_card_played)
	EventBus.tile_card_selected.connect(_add_tile_card)
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
		var starting_runes := PlayerCharacter.get_starting_hand_runes(character)
		for rune in starting_runes:
			_add_tile_card(rune)

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
func _get_hand_card_count() -> int:
	return _get_hand_cards().size()


func _get_hand_cards() -> Array[CardUI]:
	var cards: Array[CardUI] = []
	for child in get_children():
		if child is CardUI:
			cards.append(child as CardUI)
	return cards


# Called from CardUI when a hand card lifts or settles so neighbors can slide aside.
func notify_card_featured(card: CardUI, featured: bool, animate: bool = true) -> void:
	if featured:
		_featured_card = card
	elif _featured_card == card:
		_featured_card = null
	_apply_hover_spread(animate)


func _refresh_hand_layout() -> void:
	if not is_inside_tree():
		return
	if _featured_card != null and _featured_card.get_parent() != self:
		_featured_card = null
	_update_card_overlap()
	_apply_hover_spread(true)


func _update_card_overlap() -> void:
	add_theme_constant_override("separation", _compute_hand_separation())


func _compute_hand_separation() -> int:
	var cards := _get_hand_cards()
	var count := cards.size()
	if count <= SPACED_HAND_COUNT:
		return _base_separation

	var card_width := _get_card_width()
	# Keep the packed row about as wide as a five-card hand.
	var target_width := SPACED_HAND_COUNT * card_width + (SPACED_HAND_COUNT - 1) * _base_separation
	var packed_sep := (target_width - count * card_width) / float(count - 1)
	var min_sep := -(card_width - MIN_VISIBLE_CARD_WIDTH)
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
	var cards := _get_hand_cards()
	# Typed Array.find() rejects null. Skip the lookup when nothing is featured.
	var featured_index := cards.find(_featured_card) if _featured_card != null else -1
	var push := _get_hover_push_amount() if featured_index >= 0 else 0.0
	for i in cards.size():
		var card := cards[i]
		if is_preserving_offset_for(card):
			continue
		var spread := 0.0
		if featured_index >= 0 and i != featured_index:
			spread = -push if i < featured_index else push
		card.set_hand_spread_x(spread, animate)


func _on_card_played(_card_ui: CardUI) -> void:
	cards_played += 1
	## Wait for the played card's queue_free() before checking remaining hand size.
	await get_tree().create_timer(0.1).timeout
	if _get_hand_card_count() < 3:
		EventBus.turn_ended.emit()
		AudioManager.play_sfx(UISounds.END_TURN)


func _hide_hand() -> void:
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


func _animate_hand_slide(hide: bool) -> void:
	if _hand_slide_tween and _hand_slide_tween.is_valid():
		_hand_slide_tween.kill()
		_hand_slide_tween = null

	var slide_distance := _get_hand_slide_distance()
	var target_y := slide_distance if hide else 0.0

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

		if hide:
			# Drop hover lift so the slide starts from the layout slot, not an elevated pose.
			card.set_hover_elevated(false, false)
			# offset_transform is visual-only by default; block clicks while off-screen.
			card.mouse_filter = Control.MOUSE_FILTER_IGNORE

		card.offset_transform_enabled = true
		var step := _hand_slide_tween.tween_property(
			card,
			"offset_transform_position",
			Vector2(card.get_hand_spread_x(), target_y),
			HAND_SLIDE_DURATION
		)
		step.set_ease(Tween.EASE_IN if hide else Tween.EASE_OUT)
		step.set_trans(Tween.TRANS_QUART)

	if animated_cards == 0:
		_hand_slide_tween.kill()
		_hand_slide_tween = null
		return

	if not hide:
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
		# Writes "tile_card". Older saves used "rune".
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
	for entry: Dictionary in state.get("cards", []):
		var kind: String = entry.get("kind", "")
		var card_id: String = entry.get("id", "")
		if kind == "tile_card" or kind == "rune":
			var tile_card := GameManager.get_tile_card_by_id(card_id)
			if tile_card != null:
				_add_tile_card(tile_card)

	_generated_reveal.restore_pending(state.get("pending_generated_cards", []))
