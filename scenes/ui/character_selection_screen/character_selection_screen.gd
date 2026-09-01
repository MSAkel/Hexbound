extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")

@onready var layout_details: LayoutDetails = %LayoutDetails
@onready var difficulty_container: DifficultyLevelContainer = %DifficultyLevelContainer
@onready var seeded_run_panel: SeededRunPanel = %SeededRunPanel
@onready var scene_enter_transition: SceneEnterTransition = $SceneEnterTransition

# One selection per character definition. Only one is shown at a time.
var selections: Array[CharacterDefinition] = []
var current_index: int = 0


func _ready() -> void:
	get_tree().paused = false

	selections = PlayerCharacter.get_all_characters()

	var previous_run_transition := RunSaveManager.consume_scene_enter_transition_request()
	_restore_last_character()
	_update_display()
	if previous_run_transition:
		difficulty_container.display_difficulty(GameManager.selected_difficulty)
		await scene_enter_transition.play()
	else:
		scene_enter_transition.queue_free()

	var music := SOUNDTRACK.get_music_for_scene(scene_file_path)
	if music:
		AudioManager.play_music(music)
	SegmentPassiveUnlockPresenter.present_if_needed(self)


func get_selected_character() -> CharacterDefinition:
	return selections[current_index]


func _restore_last_character() -> void:
	GameSettings.ensure_loaded()
	var character_id := GameSettings.last_character_selection_id
	# Fall back to the last run character when settings have no stored selection yet.
	if character_id.is_empty() and GameManager.selected_character != null:
		character_id = GameManager.selected_character.id
	if character_id.is_empty():
		return

	for index in selections.size():
		if selections[index].id == character_id:
			current_index = index
			return


func _on_prev_selection_pressed() -> void:
	current_index = (current_index - 1 + selections.size()) % selections.size()
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)


func _on_next_selection_pressed() -> void:
	current_index = (current_index + 1) % selections.size()
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)


func _update_display() -> void:
	layout_details.display_selection(get_selected_character())
	GameSettings.set_last_character_selection_id(get_selected_character().id)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _on_play_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)

	# A fresh run replaces any saved session from a previous quit.
	# delete_save also clears Continue-pending so main.tscn cannot restore that file.
	RunSaveManager.delete_save()

	var selected_character := layout_details.get_selected_character()
	# Character choice locks in layout rules for the entire run.
	GameManager.selected_character = selected_character
	GameManager.selected_difficulty = difficulty_container.get_selected_difficulty()
	GameManager.apply_active_segment_passives(selected_character.id)
	RunSaveManager.set_pending_run_seed(seeded_run_panel.get_effective_seed_text())
	RunSaveManager.request_scene_enter_transition()

	get_tree().change_scene_to_file(ScenePaths.MAIN)
