extends Node2D

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")

func _ready() -> void:
	# Set starting gold after character selection has chosen selected_character.
	GameManager.reset_gold()

	# Check if music is playing and play if it's not
	if not AudioManager.music_player.playing:
		var music = SOUNDTRACK.get_music_for_scene(scene_file_path)
		if music:
			AudioManager.play_music(music)
