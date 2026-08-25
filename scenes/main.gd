extends Node2D

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")

@export_category("Debug")
## Round used when starting a fresh run. Continued runs always use their saved round.
@export_range(1, 100, 1, "or_greater") var debug_starting_round: int = 1

@onready var camera: Camera2D = $Camera
@onready var hand: Hand = $MainUI/CardsHand/Hand
@onready var tile_map: HexTileMap = $HexTileMap
@onready var scene_enter_transition: SceneEnterTransition = $SceneEnterTransition


func _ready() -> void:
	var play_entry_transition := RunSaveManager.consume_scene_enter_transition_request()
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
