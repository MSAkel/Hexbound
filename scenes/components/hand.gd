class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")
const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

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
	add_child(new_rune_card)
	new_rune_card.set_card(data)
	new_rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
)

func _on_card_played(_card_ui: CardUI) -> void:
	cards_played += 1
	# Chck how many cards are in hand, if it less than 3, end the turn
	# await on the next frame
	await get_tree().create_timer(0.1).timeout
	if get_child_count() < 3:
		Events.turn_ended.emit()
		AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

func _hide_hand() -> void:
	for child in get_children():
		child.visible = false

func _show_hand() -> void:
	for child in get_children():
		child.visible = true
