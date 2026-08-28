class_name CharacterDetails
extends HBoxContainer

const DEFAULT_SEGMENT_COUNT := 7

signal prev_selection_pressed
signal next_selection_pressed

# Kept in sync by display_selection so Play can lock in the visible character.
var _selected_character: CharacterDefinition = null

@onready var character_name_label: Label = %CharacterNameLabel
@onready var segment_passives_button: Button = %SegmentPassivesButton
@onready var passive_set_label: Label = %PassiveSetLabel
@onready var character_icon: TextureRect = %CharacterIcon
@onready var difficulty_container: DifficultyLevelContainer = %DifficultyLevelContainer
@onready var trigger_order_label: Label = %TriggerOrderLabel
@onready var trigger_order_description: Label = %TriggerOrderDescription
@onready var trigger_order_image: TextureRect = %TriggerOrderImage
@onready var segment_count_label: Label = %SegmentCountTitle
@onready var seeded_run_panel: SeededRunPanel = %SeededRunPanel


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
	_refresh_passive_set_label(character)


func _refresh_passive_set_label(character: CharacterDefinition) -> void:
	var set_id := MetaProgressionManager.get_selected_set_id(character.id)
	passive_set_label.text = "Set %s" % set_id


func _on_segment_passives_button_pressed() -> void:
	if _selected_character == null:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	GameManager.segment_passives_editor_character = _selected_character
	get_tree().change_scene_to_file(ScenePaths.SEGMENT_PASSIVES)


func _on_prev_selection_pressed() -> void:
	prev_selection_pressed.emit()


func _on_next_selection_pressed() -> void:
	next_selection_pressed.emit()


func get_selected_difficulty() -> Difficulty.Level:
	return difficulty_container.get_selected_difficulty()


func display_difficulty(level: Difficulty.Level) -> void:
	difficulty_container.display_difficulty(level)


func _on_play_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)

	# A fresh run replaces any saved session from a previous quit.
	RunSaveManager.delete_save()

	# Character choice locks in layout rules for the entire run.
	GameManager.selected_character = _selected_character
	GameManager.selected_difficulty = get_selected_difficulty()
	GameManager.apply_active_segment_passives(_selected_character.id)
	RunSaveManager.set_pending_run_seed(seeded_run_panel.get_effective_seed_text())
	RunSaveManager.request_scene_enter_transition()

	get_tree().change_scene_to_file(ScenePaths.MAIN)
