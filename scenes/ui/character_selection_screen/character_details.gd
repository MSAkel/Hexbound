class_name SelectionDetails
extends HBoxContainer

signal prev_selection_pressed
signal next_selection_pressed

const CARD_UI_SCENE := preload("uid://dt0t3awb0mejg")


@onready var character_name_label: RichTextLabel = $SlectionDetails/HBoxContainer/Panel/CharacterNameLabel
@onready var difficulty_container: HBoxContainer = $SlectionDetails/DifficultyLevelContainer
@onready var trigger_order_label: Label = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderLabel
@onready var trigger_order_description: Label = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderDescription
@onready var trigger_order_image: TextureRect = $SlectionTriggerOrder/triggerOrderPanel/MarginContainer/VBoxContainer/TriggerOrderImage
@onready var segment_label: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentLabel
@onready var segment_description: Label = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentDescription
@onready var segment_image: TextureRect = $SlectionTriggerOrder/SegmentsPanel/MarginContainer/VBoxContainer/SegmentImage

func display_selection(character_type: PlayerCharacter.Type) -> void:
	character_name_label.text = "[wave amp=50 freq=2]%s[/wave]" %  PlayerCharacter.get_character_name(character_type)

	var trigger_order: TriggerOrderType.Type = PlayerCharacter.get_trigger_order(character_type)
	trigger_order_label.text = TriggerOrderType.get_display_name(trigger_order)
	trigger_order_description.text = TriggerOrderType.get_description(trigger_order)
	trigger_order_image.texture = TriggerOrderType.get_preview_texture(trigger_order)

	segment_label.text = PlayerCharacter.get_segment_passive_name(character_type)
	segment_description.text = PlayerCharacter.get_segment_passive_description(character_type)
	segment_image.texture = SegmentPassiveModifier.get_map_texture_for_character(character_type)

func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()


func get_selected_difficulty() -> Difficulty.Level:
	return difficulty_container.get_selected_difficulty()
