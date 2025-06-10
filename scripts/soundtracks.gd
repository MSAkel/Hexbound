extends Resource
class_name Music

# Preload all music tracks
const MAIN_THEME = preload("res://assets/audio/music/main_theme.mp3")

# Get the appropriate music for a scene
static func get_music_for_scene(scene_path: String) -> AudioStream:
	match scene_path:
		"res://scenes/ui/main_menu/main_menu.tscn":
			return MAIN_THEME
		"res://scenes/ui/boons_selection/boons_selection.tscn":
			return MAIN_THEME
		"res://scenes/main.tscn":
			return MAIN_THEME
		_:
			return null 
