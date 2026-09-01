class_name LayoutDetails
extends HBoxContainer

const DEFAULT_SEGMENT_COUNT := 7

# Kept in sync by display_selection so Play can lock in the visible layout.
var _selected_character: CharacterDefinition = null

@onready var character_name_label: Label = %CharacterNameLabel
@onready var layout_level_label: Label = %LayoutLevelLabel
@onready var layout_xp_label: Label = %LayoutXpLabel
@onready var passive_set_label: Label = %PassiveSetLabel
@onready var character_icon: TextureRect = %CharacterIcon
@onready var trigger_order_label: Label = %TriggerOrderLabel
@onready var trigger_order_description: Label = %TriggerOrderDescription
@onready var trigger_order_image: TextureRect = %TriggerOrderImage
@onready var segment_count_label: Label = %SegmentCountTitle


func display_selection(character: CharacterDefinition) -> void:
	_selected_character = character
	character_name_label.text = character.display_name.to_upper()
	character_icon.texture = character.icon
	trigger_order_label.text = character.trigger_order_display_name.to_upper()
	trigger_order_description.text = character.trigger_order_description
	trigger_order_image.texture = character.trigger_order_preview

	var segment_count := DEFAULT_SEGMENT_COUNT
	if not character.segment_starts.is_empty():
		segment_count = character.segment_starts.size()
	elif character.segments_count > 0:
		segment_count = character.segments_count
	segment_count_label.text = "%d SEGMENTS" % segment_count
	_refresh_layout_progress(character)
	_refresh_passive_set_label(character)


func get_selected_character() -> CharacterDefinition:
	return _selected_character


func _refresh_layout_progress(character: CharacterDefinition) -> void:
	var level := MetaProgressionManager.get_layout_level(character.id)
	layout_level_label.text = "Level %d" % level
	if level >= MetaProgressionManager.LAYOUT_LEVEL_XP.size():
		layout_xp_label.hide()
		return
	var xp := MetaProgressionManager.get_layout_xp(character.id)
	var next_xp := MetaProgressionManager.get_layout_xp_for_next_level(character.id)
	layout_xp_label.text = "%d/%d EXP" % [xp, next_xp]
	layout_xp_label.show()


func _refresh_passive_set_label(character: CharacterDefinition) -> void:
	var set_id := MetaProgressionManager.get_selected_set_id(character.id)
	passive_set_label.text = "Set %s" % set_id


func _on_segment_passives_button_pressed() -> void:
	if _selected_character == null:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	GameManager.segment_passives_editor_character = _selected_character
	get_tree().change_scene_to_file(ScenePaths.SEGMENT_PASSIVES)
