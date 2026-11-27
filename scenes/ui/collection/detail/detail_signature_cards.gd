class_name CollectionDetailSignatureCards
extends VBoxContainer

## Chef page: the chef's signature cards in unlock order. A reached card shows as the real card
## (hover for its tooltip); a locked one as an empty frame with its chef level.

const CARD_UI_SCENE := preload("res://scenes/cards/card_ui/card_ui.tscn")
const LOCKED_SCENE := preload("res://scenes/ui/collection/detail/signature_card_locked.tscn")
const CARD_BASE_SIZE := Vector2(214, 317)

## Card size on the page. The locked frame's minimum size matches it.
@export var card_scale := 0.62

@onready var _slots: HBoxContainer = %Slots


## entries: [{"card_id", "level"}] from ChefProgression.
func setup(entries: Array[Dictionary], chef_level: int) -> void:
	if not is_node_ready():
		await ready
	for entry: Dictionary in entries:
		var required := int(entry.get("level", 0))
		var template := GameManager.get_tile_card_by_id(String(entry.get("card_id", "")))
		if chef_level >= required and template != null:
			_add_card(template)
		else:
			var locked := LOCKED_SCENE.instantiate() as CollectionSignatureCardLocked
			_slots.add_child(locked)
			locked.setup(required)


func _add_card(template: TileCard) -> void:
	var slot := Control.new()
	slot.custom_minimum_size = CARD_BASE_SIZE * card_scale
	slot.mouse_filter = Control.MOUSE_FILTER_PASS
	_slots.add_child(slot)
	var card_ui: CardUI = CARD_UI_SCENE.instantiate()
	slot.add_child(card_ui)
	card_ui.scale = Vector2.ONE * card_scale
	card_ui.configure_interaction(CardUI.InteractionMode.PREVIEW)
	card_ui.set_card(template)
