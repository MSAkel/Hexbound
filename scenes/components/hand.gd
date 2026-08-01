class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://dt0t3awb0mejg")

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	Events.card_played.connect(func(_card_ui: CardUI):
		cards_played += 1
	)

	# Starting hand depends on the character selected before the run begins
	var starting_runes := PlayerCharacter.get_starting_hand_runes(GameManager.selected_character)
	for rune in starting_runes:
		add_rune_card(rune)

	Events.rune_selected.connect(add_rune_card)


func add_rune_card(rune: Rune) -> void:
	var new_rune_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(new_rune_card)
	new_rune_card.set_card(rune)
	new_rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
)
