class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")
# Slide the hand off-screen between turns using 4.7 offset transforms (layout-safe).
const HAND_SLIDE_DURATION := 0.35
# Stagger between each card during the run-start entrance from below.
const INTRO_CARD_STAGGER := 0.07

# Test-only enhancements dealt at run start. Clear this array when done testing.
const DEBUG_STARTING_ENHANCEMENTS: Array[Enhancement] = [
	#preload("uid://dcn24d4g51dc6"),
]

# Keep starting cards parked off-screen until Main finishes fade/zoom.
var _awaiting_intro := true

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	EventBus.card_played.connect(_on_card_played)
	EventBus.rune_selected.connect(_add_rune_card)
	EventBus.enhancement_selected.connect(_add_enhancement_card)
	EventBus.turn_ended.connect(_hide_hand)
	EventBus.turn_started.connect(_show_hand)

	# Saved runs rebuild the hand after the main scene finishes loading.
	if RunSaveManager.should_restore_run():
		return

	# Starting hand depends on the character selected before the run begins
	var starting_runes := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	for rune in starting_runes:
		_add_rune_card(rune)

	for enhancement in DEBUG_STARTING_ENHANCEMENTS:
		_add_enhancement_card(enhancement)

	# Snap immediately so the first frame never flashes cards at rest before the intro.
	if _awaiting_intro:
		_snap_hand_offscreen()


func _add_rune_card(rune: Rune) -> void:
	_add_card(rune)


func _add_enhancement_card(enhancement: Enhancement) -> void:
	_add_card(enhancement)


func _add_card(data: Resource) -> void:
	var new_rune_card := CARD_UI_SCENE.instantiate() as CardUI
	new_rune_card.configure_interaction(CardUI.InteractionMode.HAND)
	add_child(new_rune_card)
	new_rune_card.set_card(data)
	new_rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, _get_hand_card_count())
		move_child.call_deferred(child, new_index)
	)
	# Cards dealt during the enter-run intro stay hidden below the viewport.
	if _awaiting_intro:
		_snap_card_offscreen(new_rune_card)


# Guard against non-card children
func _get_hand_card_count() -> int:
	var count := 0
	for child in get_children():
		if child is CardUI:
			count += 1
	return count


func _on_card_played(_card_ui: CardUI) -> void:
	cards_played += 1
	# Wait for the played card's queue_free() before checking remaining hand size.
	await get_tree().create_timer(0.1).timeout
	if _get_hand_card_count() < 3:
		EventBus.turn_ended.emit()
		AudioManager.play_sfx(UI_SOUNDS.END_TURN)

var _hand_slide_tween: Tween = null


func _hide_hand() -> void:
	_animate_hand_slide(true)


func _show_hand() -> void:
	# Don't fight the run-start entrance if a turn signal fires early.
	if _awaiting_intro:
		return
	_animate_hand_slide(false)


## True while starting cards should stay parked below the viewport.
func is_awaiting_intro() -> bool:
	return _awaiting_intro


## After fade/zoom, slide each starting card up from below with a light stagger.
func play_intro_entrance() -> void:
	# CardBaseState waits one frame then clears hover offset to ZERO — wait past that,
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

	# Intro offset is now owned by the tween; allow normal hover afterward.
	_awaiting_intro = false

	if animated_cards == 0:
		_hand_slide_tween.kill()
		_hand_slide_tween = null
		_restore_card_mouse_filters()
		return

	await _hand_slide_tween.finished
	_hand_slide_tween = null
	_restore_card_mouse_filters()


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
		if child is CardUI:
			child.mouse_filter = Control.MOUSE_FILTER_STOP


func _animate_hand_slide(hide: bool) -> void:
	if _hand_slide_tween and _hand_slide_tween.is_valid():
		_hand_slide_tween.kill()
		_hand_slide_tween = null

	var slide_distance := _get_hand_slide_distance()
	var target_offset := Vector2(0, slide_distance) if hide else Vector2.ZERO

	_hand_slide_tween = create_tween()
	_hand_slide_tween.set_parallel(true)

	var animated_cards := 0
	for child in get_children():
		if not child is CardUI:
			continue
		var card := child as CardUI
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
			target_offset,
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
		if card_ui.card is Rune:
			cards.append({"kind": "rune", "id": (card_ui.card as Rune).id})
		elif card_ui.card is Enhancement:
			cards.append({"kind": "enhancement", "id": (card_ui.card as Enhancement).id})

	return {
		"cards": cards,
		"cards_played": cards_played,
	}


func restore_hand_state(state: Dictionary) -> void:
	# Park restored cards off-screen, main.gd replays the hand intro afterward.
	_awaiting_intro = true

	for child in get_children():
		if child is CardUI:
			remove_child(child)
			child.free()

	cards_played = int(state.get("cards_played", 0))
	for entry: Dictionary in state.get("cards", []):
		var kind: String = entry.get("kind", "")
		var card_id: String = entry.get("id", "")
		if kind == "rune":
			var rune := GameManager.get_rune_by_id(card_id)
			if rune != null:
				_add_rune_card(rune)
		elif kind == "enhancement":
			var enhancement := GameManager.get_enhancement_by_id(card_id)
			if enhancement != null:
				_add_enhancement_card(enhancement)
