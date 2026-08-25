extends Node2D

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")
const INTRO_HOLD_DURATION := 1.5
const INTRO_FADE_DURATION := 0.85
const RUNE_FLOAT_DISTANCE := 12.0
const RUNE_FLOAT_DURATION := 0.9
const INTRO_RUNE_TEXTURES: Array[Texture2D] = [
	preload("res://assets/icons/runes/support/unstable_rune.png"),
	preload("res://assets/icons/runes/support/radiant_link.png"),
	preload("res://assets/icons/runes/hybrid/unstable_concoction.png"),
	preload("res://assets/icons/runes/modifier/gold_extraction.png"),
	preload("res://assets/icons/runes/production/golden_ratio.png"),
	preload("res://assets/icons/runes/production/overcharge.png"),
]

@export_category("Debug")
## Round used when starting a fresh run. Continued runs always use their saved round.
@export_range(1, 100, 1, "or_greater") var debug_starting_round: int = 1

@onready var camera: Camera2D = $Camera
@onready var hand: Hand = $MainUI/CardsHand/Hand
@onready var tile_map: HexTileMap = $HexTileMap
@onready var intro_fade_layer: CanvasLayer = $IntroFadeLayer
@onready var intro_fade: ColorRect = $IntroFadeLayer/IntroFade
@onready var intro_rune: TextureRect = $IntroFadeLayer/IntroRune


func _ready() -> void:
	var play_entry_transition := RunSaveManager.consume_main_scene_transition_request()
	if play_entry_transition:
		intro_fade_layer.show()
	else:
		intro_fade_layer.queue_free()

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
		await _play_scene_enter_animation()

	if hand:
		await hand.play_intro_entrance()

	# Check if music is playing and play if it's not
	if not AudioManager.music_player.playing:
		var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
		if music:
			AudioManager.play_music(music)


## Holds on a randomly chosen floating rune, then reveals the newly loaded run.
func _play_scene_enter_animation() -> void:
	intro_rune.texture = INTRO_RUNE_TEXTURES.pick_random()
	intro_rune.pivot_offset = intro_rune.size * 0.5
	intro_rune.modulate.a = 0.0
	intro_rune.scale = Vector2(0.78, 0.78)

	var reveal_tween := create_tween()
	reveal_tween.set_ease(Tween.EASE_OUT)
	reveal_tween.set_trans(Tween.TRANS_BACK)
	reveal_tween.set_parallel(true)
	reveal_tween.tween_property(intro_rune, "modulate:a", 1.0, 0.35)
	reveal_tween.tween_property(intro_rune, "scale", Vector2.ONE, 0.45)

	var start_y := intro_rune.position.y
	var float_tween := create_tween().set_loops()
	float_tween.set_trans(Tween.TRANS_SINE)
	float_tween.set_ease(Tween.EASE_IN_OUT)
	float_tween.tween_property(intro_rune, "position:y", start_y - RUNE_FLOAT_DISTANCE, RUNE_FLOAT_DURATION)
	float_tween.tween_property(intro_rune, "position:y", start_y + RUNE_FLOAT_DISTANCE, RUNE_FLOAT_DURATION)

	await get_tree().create_timer(INTRO_HOLD_DURATION).timeout

	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.set_parallel(true)
	fade_tween.tween_property(intro_fade, "modulate:a", 0.0, INTRO_FADE_DURATION)
	fade_tween.tween_property(intro_rune, "modulate:a", 0.0, INTRO_FADE_DURATION * 0.7)
	fade_tween.tween_property(intro_rune, "scale", Vector2(1.12, 1.12), INTRO_FADE_DURATION)
	await fade_tween.finished

	float_tween.kill()
	intro_fade_layer.queue_free()
