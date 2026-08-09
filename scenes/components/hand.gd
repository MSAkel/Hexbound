class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")
# Slide the hand off-screen between turns using 4.7 offset transforms (layout-safe).
const HAND_SLIDE_DURATION := 0.35

# Test-only enhancements dealt at run start. Clear this array when done testing.
const DEBUG_STARTING_ENHANCEMENTS: Array[Enhancement] = [
	#preload("uid://dcn24d4g51dc6"),
]

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	Events.card_played.connect(_on_card_played)
	Events.rune_selected.connect(_add_rune_card)
	Events.enhancement_selected.connect(_add_enhancement_card)
	Events.turn_ended.connect(_hide_hand)
	Events.turn_started.connect(_show_hand)

	# Starting hand depends on the character selected before the run begins
	var starting_runes := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	for rune in starting_runes:
		_add_rune_card(rune)

	for enhancement in DEBUG_STARTING_ENHANCEMENTS:
		_add_enhancement_card(enhancement)


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
		Events.turn_ended.emit()
		AudioManager.play_sfx(UI_SOUNDS.END_TURN)

var _hand_slide_tween: Tween = null


func _hide_hand() -> void:
	_animate_hand_slide(true)


func _show_hand() -> void:
	_animate_hand_slide(false)


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
			for child in get_children():
				if child is CardUI:
					child.mouse_filter = Control.MOUSE_FILTER_STOP
		)


func _get_hand_slide_distance() -> float:
	# Full viewport height guarantees cards leave the screen from the bottom edge.
	return get_viewport().get_visible_rect().size.y
