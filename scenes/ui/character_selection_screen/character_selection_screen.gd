extends Control

const SOUNDTRACK := preload("res://scripts/soundtracks.gd")

@onready var layout_details: LayoutDetails = %LayoutDetails
@onready var difficulty_container: DifficultyLevelContainer = %DifficultyLevelContainer
@onready var seeded_run_panel: SeededRunPanel = %SeededRunPanel
@onready var scene_enter_transition: SceneEnterTransition = $SceneEnterTransition
@onready var play_button: Button = %PlayButton
@onready var abandon_run_confirm_panel: AbandonRunConfirmPanel = %AbandonRunConfirmPanel
@onready var back_button: Button = $SafeArea/Page/UnifiedPanel/Content/Header/HeaderLeft/BackButton
@onready var prev_selection_button: TextureButton = $SafeArea/Page/PrevSelectionButton
@onready var next_selection_button: TextureButton = $SafeArea/Page/NextSelectionButton

# One selection per character definition. Only one is shown at a time.
var selections: Array[CharacterDefinition] = []
var current_index: int = 0
var _layout_nav_cooldown := 0.0

const LAYOUT_NAV_COOLDOWN := 0.2


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
	abandon_run_confirm_panel.confirmed.connect(_on_abandon_run_confirmed)
	abandon_run_confirm_panel.cancelled.connect(_on_abandon_run_cancelled)
	_bind_screen_hover_sounds()
	call_deferred("_focus_character_selection")


func _process(delta: float) -> void:
	_layout_nav_cooldown = maxf(_layout_nav_cooldown - delta, 0.0)


func _focus_character_selection() -> void:
	if play_button != null and not play_button.disabled:
		play_button.grab_focus()
		return
	MenuFocus.grab_first(self)


func _bind_screen_hover_sounds() -> void:
	for button: BaseButton in [
		prev_selection_button,
		next_selection_button,
		back_button,
		play_button,
		abandon_run_confirm_panel.cancel_button,
		abandon_run_confirm_panel.confirm_button,
	]:
		_bind_menu_hover_sound(button)
	_collect_menu_hover_sounds(difficulty_container)
	_collect_menu_hover_sounds(seeded_run_panel)


func _collect_menu_hover_sounds(root: Node) -> void:
	if root is BaseButton:
		_bind_menu_hover_sound(root as BaseButton)
	for child in root.get_children():
		_collect_menu_hover_sounds(child)


func _bind_menu_hover_sound(button: BaseButton) -> void:
	button.mouse_entered.connect(_play_menu_hover_sound)
	button.focus_entered.connect(_play_menu_hover_sound)


func _play_menu_hover_sound() -> void:
	AudioManager.play_ui_hover()


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
	_step_layout(-1)


func _on_next_selection_pressed() -> void:
	_step_layout(1)


func _step_layout(direction: int) -> void:
	if _layout_nav_cooldown > 0.0:
		return
	_layout_nav_cooldown = LAYOUT_NAV_COOLDOWN
	current_index = (current_index + direction + selections.size()) % selections.size()
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)


func _update_display() -> void:
	layout_details.display_selection(get_selected_character())
	GameSettings.set_last_character_selection_id(get_selected_character().id)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		if abandon_run_confirm_panel.visible:
			abandon_run_confirm_panel.cancel()
			return
		_on_back_button_pressed()


func _on_play_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	if RunSaveManager.has_save():
		abandon_run_confirm_panel.show_panel()
		return
	_start_new_run()


func _on_abandon_run_confirmed() -> void:
	RunSaveManager.abandon_saved_run_as_loss()
	_start_new_run()


func _on_abandon_run_cancelled() -> void:
	call_deferred("_focus_character_selection")


func _start_new_run() -> void:
	var selected_character := layout_details.get_selected_character()
	# Character choice locks in layout rules for the entire run.
	GameManager.selected_character = selected_character
	GameManager.selected_difficulty = difficulty_container.get_selected_difficulty()
	GameManager.apply_active_segment_passives(selected_character.id)
	RunSaveManager.set_pending_run_seed(seeded_run_panel.get_effective_seed_text())
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file(ScenePaths.MAIN)
