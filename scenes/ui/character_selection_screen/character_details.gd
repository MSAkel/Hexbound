class_name SelectionDetails
extends HBoxContainer

signal prev_selection_pressed
signal next_selection_pressed

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")


@onready var character_name_label: RichTextLabel = $SlectionDetails/HBoxContainer/Panel/CharacterNameLabel
@onready var difficulty_container: HBoxContainer = $SlectionDetails/DifficultyLevelContainer

@onready var trigger_order_label: Label = $SlectionTriggerOrder/triggerOrderPanel/VBoxContainer/TriggerOrderLabel
@onready var trigger_order_description: Label = $SlectionTriggerOrder/triggerOrderPanel/VBoxContainer/TriggerOrderDescription
@onready var trigger_order_image: TextureRect = $SlectionTriggerOrder/triggerOrderPanel/VBoxContainer/HBoxContainer/TriggerOrderImage

@onready var segment_label: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentLabel
@onready var segment_description: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentDescription
@onready var segment_image: TextureRect = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentImage

func display_selection(character: CharacterDefinition) -> void:
	character_name_label.text = "[wave amp=50 freq=2]%s[/wave]" % character.display_name
	trigger_order_label.text = character.trigger_order_display_name
	trigger_order_description.text = character.trigger_order_description
	trigger_order_image.texture = character.trigger_order_preview
	segment_label.text = character.passive_name
	segment_description.text = character.passive_description
	segment_image.texture = character.passive_icon_preview

func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()


func get_selected_difficulty() -> Difficulty.Level:
	return difficulty_container.get_selected_difficulty()
