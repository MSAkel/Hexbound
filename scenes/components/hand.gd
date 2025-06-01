class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

const CARD_UI_SCENE := preload("res://scenes/ui/cards/card_ui.tscn")
const FARM_RESOURCE := preload("res://resources/buildings/farm.tres")
const MINE_RESOURCE := preload("res://resources/buildings/mine.tres")

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	Events.card_played.connect(func(card_ui: CardUI):
		cards_played += 1
	)

	# Create and add the farm card
	var farm_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(farm_card)
	farm_card._set_card(FARM_RESOURCE)
	farm_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
	)

	# Create and add the mine card
	var mine_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(mine_card)
	mine_card._set_card(MINE_RESOURCE)
	mine_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
	)

	# Create and add a random rune card
	var rune_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(rune_card)
	var random_rune: Rune = GameManager.runes_pool.pick_random() as Rune
	rune_card._set_card(random_rune)
	rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
	)
