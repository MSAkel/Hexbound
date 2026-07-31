class_name SelectionDetails
extends HBoxContainer

signal prev_selection_pressed
signal next_selection_pressed

@onready var passive: Label = $SlectionDetails/Passive
@onready var selection_runes: GridContainer = $SlectionDetails/SelectionRunes
@onready var trigger_order_label: Label = $SlectionTriggerOrder/TriggerOrder
@onready var trigger_order_image: TextureRect = $SlectionTriggerOrder/TriggerOrderImage


func display_selection(character_type: PlayerCharacter.Type) -> void:
	passive.text = PlayerCharacter.get_passive_description(character_type)

	var trigger_order: TriggerOrderType.Type = PlayerCharacter.get_trigger_order(character_type)
	trigger_order_label.text = TriggerOrderType.get_display_name(trigger_order)
	trigger_order_image.texture = TriggerOrderType.get_preview_texture(trigger_order)

	_update_runes_preview(character_type)


# Unique rune sets are not finalized yet. Show a placeholder until they are defined.
func _update_runes_preview(_character_type: PlayerCharacter.Type) -> void:
	for child in selection_runes.get_children():
		child.queue_free()

	var placeholder := Label.new()
	placeholder.text = "Unique rune set: TBD"
	placeholder.add_theme_font_size_override("font_size", 20)
	selection_runes.add_child(placeholder)


func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()
