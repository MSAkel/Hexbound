class_name SelectionDetails
extends HBoxContainer

signal prev_selection_pressed
signal next_selection_pressed

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")

@onready var character_name_label: Label = $SlectionDetails/CharacterNameLabel
@onready var starting_hand_grid_container: GridContainer = $SlectionDetails/HBoxContainer/StartingHandPanel/StartingHandGridContainer
@onready var trigger_order_label: Label = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderLabel
@onready var trigger_order_description: Label = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderDescription
@onready var trigger_order_image: TextureRect = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderImage
@onready var segment_label: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentLabel
@onready var segment_description: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentDescription
@onready var segment_image: TextureRect = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentImage

func display_selection(character_type: PlayerCharacter.Type) -> void:
	character_name_label.text = PlayerCharacter.get_character_name(character_type)
	_update_starting_hand(character_type)

	var trigger_order: TriggerOrderType.Type = PlayerCharacter.get_trigger_order(character_type)
	trigger_order_label.text = TriggerOrderType.get_display_name(trigger_order)
	trigger_order_description.text = TriggerOrderType.get_description(trigger_order)
	trigger_order_image.texture = TriggerOrderType.get_preview_texture(trigger_order)

	segment_label.text = PlayerCharacter.get_segment_passive_name(character_type)
	segment_description.text = PlayerCharacter.get_segment_passive_description(character_type)
	segment_image.texture = SegmentPassiveModifier.get_map_texture_for_character(character_type)


# Rebuild the preview row whenever the player cycles characters.
func _update_starting_hand(character_type: PlayerCharacter.Type) -> void:
	for child in starting_hand_grid_container.get_children():
		child.queue_free()

	for rune in PlayerCharacter.get_starting_hand_runes(character_type):
		var card_ui := CARD_UI_SCENE.instantiate() as CardUI
		# Character select cards are display-only; skip hover lift and clicks.
		card_ui.hover_enabled = false
		card_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
		starting_hand_grid_container.add_child(card_ui)
		card_ui.set_card(rune)

func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()
