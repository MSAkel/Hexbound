extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")
const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var character_details: CharacterDetails = $SafeArea/Page/CharacterDetails
@onready var scene_enter_transition: SceneEnterTransition = $SceneEnterTransition

# One selection per character definition; only one is shown at a time.
var selections: Array[CharacterDefinition] = []
var current_index: int = 0


func _ready() -> void:
	get_tree().paused = false

	selections = PlayerCharacter.get_all_characters()
	character_details.prev_selection_pressed.connect(_on_prev_selection)
	character_details.next_selection_pressed.connect(_on_next_selection)

	var previous_run_transition := RunSaveManager.consume_scene_enter_transition_request()
	_restore_last_character()
	_update_display()
	if previous_run_transition:
		character_details.display_difficulty(GameManager.selected_difficulty)
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


func _on_prev_selection() -> void:
	current_index = (current_index - 1 + selections.size()) % selections.size()
	_update_display()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _on_next_selection() -> void:
	current_index = (current_index + 1) % selections.size()
	_update_display()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _update_display() -> void:
	# Name, trigger order, and difficulty are shown inside CharacterDetails.
	character_details.display_selection(get_selected_character())
	GameSettings.set_last_character_selection_id(get_selected_character().id)

func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)
