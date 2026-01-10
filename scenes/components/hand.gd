class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

#TODO Max hand size

const CARD_UI_SCENE = preload("uid://b4k5fq6ran8f5")
const MINTING_FACILITY = preload("uid://deb1u0q0rx5rn")
const FARM = preload("uid://dgo4id0ggu2an")
const QUARRY = preload("uid://bvlpow8ra5pj7")
const LUMBER_CAMP = preload("uid://q830kt50p7jk")
const BASIC_RUNE = preload("uid://c7c2eo74m8q0l")

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	Events.card_played.connect(func(_card_ui: CardUI):
		cards_played += 1
	)


	# Default starting hand, might be updated to based on selected advisor
	add_building_card(MINTING_FACILITY)
	add_building_card(FARM)
	add_building_card(QUARRY)
	add_building_card(LUMBER_CAMP)
	add_rune_card(BASIC_RUNE)

	# Adds a random rune to hand
	# var random_rune: Rune = GameManager.runes_pool.pick_random() as Rune
	# add_rune_card(random_rune)

	Events.building_selected.connect(add_building_card)
	Events.rune_selected.connect(add_rune_card)


func add_building_card(building: Building) -> void:
	var new_building_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(new_building_card)
	new_building_card.set_card(building)
	new_building_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
)

func add_rune_card(rune: Rune) -> void:
	var new_rune_card := CARD_UI_SCENE.instantiate() as CardUI
	add_child(new_rune_card)
	new_rune_card.set_card(rune)
	new_rune_card.reparent_requested.connect(func(child: CardUI):
		child.reparent(self)
		var new_index := clampi(child.starting_hand_position - cards_played, 0, get_child_count())
		move_child.call_deferred(child, new_index)
)
