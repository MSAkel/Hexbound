class_name CharacterDetails
extends HBoxContainer

signal prev_selection_pressed
signal next_selection_pressed
signal play_pressed


@onready var character_name_label: RichTextLabel = $VBoxContainer/HBoxContainer/SelectionContainer/SelectionVContainer/CharacterPanel/VBoxContainer/CharacterNameLabel
@onready var character_icon: TextureRect = $VBoxContainer/HBoxContainer/SelectionContainer/SelectionVContainer/CharacterPanel/VBoxContainer/CharacterIcon
@onready var difficulty_container: PanelContainer = $VBoxContainer/HBoxContainer2/DifficultyPanel/DifficultyLevelContainer

@onready var trigger_order_label: Label = $VBoxContainer/HBoxContainer/triggerOrderPanel/VBoxContainer/TriggerOrderLabel
@onready var trigger_order_description: Label = $VBoxContainer/HBoxContainer/triggerOrderPanel/VBoxContainer/TriggerOrderDescription
@onready var trigger_order_image: TextureRect = $VBoxContainer/HBoxContainer/triggerOrderPanel/VBoxContainer/HBoxContainer/TriggerOrderImage

@onready var passive_icon: TextureRect = $VBoxContainer/HBoxContainer/SelectionContainer/SelectionVContainer/PassivesContainer/PassiveIcon
@onready var passive_name: Label = $VBoxContainer/HBoxContainer/SelectionContainer/SelectionVContainer/PassivesContainer/PassiveInfoContainer/PassiveName
@onready var passive_description: Label = $VBoxContainer/HBoxContainer/SelectionContainer/SelectionVContainer/PassivesContainer/PassiveInfoContainer/PassiveDescription

@onready var segment_count_label: Label = $VBoxContainer/HBoxContainer/triggerOrderPanel/VBoxContainer/HBoxContainer/LegendContainer/VBoxContainer/SegmentsContainer/VBoxContainer/ItemTitle


func display_selection(character: CharacterDefinition) -> void:
	character_name_label.text = "[wave amp=50 freq=2]%s[/wave]" % character.display_name
	character_icon.texture = character.icon
	trigger_order_label.text = character.trigger_order_display_name
	trigger_order_description.text = character.trigger_order_description
	trigger_order_image.texture = character.trigger_order_preview
	passive_name.text = character.passive_name
	passive_description.text = character.passive_description
	passive_icon.texture = character.passive_icon_preview
	# Numbered-grid characters define segments explicitly; others keep the scene placeholder.
	if not character.segment_starts.is_empty():
		segment_count_label.text = "Segments: %d" % character.segment_starts.size()


func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()


func get_selected_difficulty() -> Difficulty.Level:
	return difficulty_container.get_selected_difficulty()


func _on_play_button_pressed() -> void:
	play_pressed.emit()
