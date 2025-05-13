class_name VillagerCard
extends Card

enum Target {BUILDING, RUINS}
enum Type {VILLAGER, GATHERER, HUNTER, WARRIOR, EXPLORER}

@export_group("Card Attributes")
#@export var id: String
@export var type : Type
@export var target: Target
#@export var value: int
@export var health: int = 5
#@export var card_slots: int = -1

#@export_group("Card Visuals")
#@export var icon: Texture2D
#@export var label: String

#@export_multiline var tooltip_text: String

#var assigned_cards: Array[Node] = []

func is_targeting_building() -> bool:
	return target == Target.BUILDING

func on_specialize_vilalger(specialization: Type) -> void:
	if !specialization:
		return
	
	type = specialization
