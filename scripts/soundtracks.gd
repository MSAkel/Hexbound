extends Resource
class_name Music

# Preload all music tracks
const MAIN_MENU_MUSIC = preload("res://assets/audio/music/main_theme.mp3")
const BOONS_SELECTION_MUSIC = preload("res://assets/audio/music/main_theme.mp3")
const GAMEPLAY_MUSIC = preload("res://assets/audio/music/main_theme.mp3")

# Get the appropriate music for a scene
static func get_music_for_scene(scene_path: String) -> AudioStream:
	match scene_path:
		"res://scenes/ui/main_menu/main_menu.tscn":
			return MAIN_MENU_MUSIC
		"res://scenes/ui/boons_selection/boons_selection.tscn":
			return BOONS_SELECTION_MUSIC
		"res://scenes/main.tscn":
			return GAMEPLAY_MUSIC
		_:
			return null 
