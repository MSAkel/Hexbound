extends Node2D

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")
const RUN_SANDBOX_OVERLAY := preload("res://scenes/debug/run_sandbox_overlay.tscn")
const RESTART_HOLD_DURATION := 1.5

@export_category("Debug")
## Round used when starting a fresh run. Continued runs always use their saved round.
@export_range(1, 100, 1, "or_greater") var debug_starting_round: int = 1

@onready var camera: Camera2D = $Camera
@onready var hand: Hand = $MainUI/CardsHand/Hand
@onready var tile_map: HexTileMap = $HexTileMap
@onready var scene_enter_transition: SceneEnterTransition = $SceneEnterTransition
@onready var pause_menu: Control = $MainUI/PauseMenu
@onready var game_over_screen: Control = $MainUI/GameOverScreen
@onready var victory_screen: Control = $MainUI/VictoryScreen
@onready var settings_container: Control = $MainUI/SettingsContainer

var _restart_hold_active := false
var _restart_hold_time := 0.0
var _is_restarting := false


func _ready() -> void:
	var play_entry_transition := RunSaveManager.consume_scene_enter_transition_request()
	# Debug-only cheat panel for completing rounds, passing turns, and injecting cards.
	if OS.is_debug_build():
		add_child(RUN_SANDBOX_OVERLAY.instantiate())

	if play_entry_transition:
		scene_enter_transition.show()
	else:
		scene_enter_transition.queue_free()

	var is_continue_run := RunSaveManager.should_restore_run()

	if is_continue_run:
		RunSaveManager.restore_run(hand, tile_map)
		RunSaveManager.clear_continue_run_pending()
	else:
		GameManager.reset_for_new_run()
		# Set starting gold after character selection has chosen the run difficulty.
		GoldManager.set_run_starting_gold(GameManager.selected_difficulty)
		ChallengeManager.init_run()
		if debug_starting_round > 1:
			GameManager.set_starting_round_for_debug(debug_starting_round)

	if play_entry_transition:
		await scene_enter_transition.play()

	if hand:
		await hand.play_intro_entrance()

	# Check if music is playing and play if it's not
	if not AudioManager.music_player.playing:
		var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
		if music:
			AudioManager.play_music(music)


func _input(event: InputEvent) -> void:
	if _is_restarting:
		return
	if event.is_action_pressed("restart_run"):
		if _can_hold_restart():
			_begin_restart_hold()
	elif event.is_action_released("restart_run"):
		_cancel_restart_hold()


func _process(delta: float) -> void:
	if not _restart_hold_active:
		return
	if not _can_hold_restart() or not Input.is_action_pressed("restart_run"):
		_cancel_restart_hold()
		return
	_restart_hold_time += delta
	if _restart_hold_time >= RESTART_HOLD_DURATION:
		_commit_restart()


## Restart is only for a living run. Pause, settings, and end screens do not count.
func _can_hold_restart() -> bool:
	if _is_restarting:
		return false
	if is_instance_valid(scene_enter_transition) and scene_enter_transition.visible:
		return false
	if _is_control_visible(pause_menu):
		return false
	if _is_control_visible(settings_container):
		return false
	if _is_control_visible(game_over_screen):
		return false
	if _is_control_visible(victory_screen):
		return false
	return true


func _is_control_visible(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree()


func _begin_restart_hold() -> void:
	if _restart_hold_active:
		return
	_restart_hold_active = true
	_restart_hold_time = 0.0


func _cancel_restart_hold() -> void:
	if _is_restarting or not _restart_hold_active:
		return
	_restart_hold_active = false
	_restart_hold_time = 0.0


func _commit_restart() -> void:
	_restart_hold_active = false
	_is_restarting = true
	# A restarted run is a new session. Drop any in-progress save for this character.
	RunSaveManager.delete_save()
	# Hold registered. Play the same enter transition used when starting a fresh run.
	RunSaveManager.request_scene_enter_transition()
	get_tree().change_scene_to_file(ScenePaths.MAIN)
