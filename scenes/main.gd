extends Node2D

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")
# Match camera intro length so fade and zoom feel like one reveal.
const INTRO_FADE_DURATION := 1.5

@onready var camera: Camera2D = $Camera
@onready var hand: Hand = $MainUI/CardsHand/Hand
@onready var intro_fade_layer: CanvasLayer = $IntroFadeLayer
@onready var intro_fade: ColorRect = $IntroFadeLayer/IntroFade


func _ready() -> void:
	# Set starting gold after character selection has chosen the run difficulty.
	GoldManager.set_run_starting_gold(GameManager.selected_difficulty)
	ChallengeManager.init_run()

	# Check if music is playing and play if it's not
	if not AudioManager.music_player.playing:
		var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
		if music:
			AudioManager.play_music(music)

	# Reveal the board, then bring the hand up from below.
	await _play_scene_enter_animation()


## Dark fade + map zoom together, then staggered hand cards from off-screen.
func _play_scene_enter_animation() -> void:
	# Fade and zoom run together; hand waits until both have settled.
	var fade_tween := create_tween()
	fade_tween.set_ease(Tween.EASE_OUT)
	fade_tween.set_trans(Tween.TRANS_QUAD)
	fade_tween.tween_property(intro_fade, "modulate:a", 0.0, INTRO_FADE_DURATION)

	if camera and camera.has_method("play_intro_zoom"):
		await camera.play_intro_zoom()

	if fade_tween.is_valid() and fade_tween.is_running():
		await fade_tween.finished

	intro_fade_layer.queue_free()

	if hand:
		await hand.play_intro_entrance()
