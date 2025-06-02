class_name Hand
extends HBoxContainer

# In a single turn
var cards_played := 0

const CARD_UI_SCENE := preload("res://scenes/ui/cards/card_ui.tscn")
const FARM_RESOURCE := preload("res://resources/buildings/farm.tres")
const MINE_RESOURCE := preload("res://resources/buildings/mine.tres")

# Reparent cards to hand when they are dragged or released
func _ready() -> void:
	Events.card_played.connect(func(_card_ui: CardUI):
		cards_played += 1
	)

	add_building_card(FARM_RESOURCE)
	add_building_card(MINE_RESOURCE)

	var random_rune: Rune = GameManager.runes_pool.pick_random() as Rune
	add_rune_card(random_rune)

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
