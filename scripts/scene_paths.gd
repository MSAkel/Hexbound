class_name ScenePaths
extends RefCounted

## Destinations for SceneTree.change_scene_to_file.
##
## Godot's SceneTree docs: use change_scene_to_file when you have a path. It
## loads a PackedScene from disk, then instantiates it. Use
## change_scene_to_packed only when you already hold a valid PackedScene
## (typically preload of a child overlay, not a mutually referencing screen).
##
## Preloading screens that instance each other yields an empty PackedScene.
## Keeping the run scene packed on the menu also holds the whole game in RAM.

const MAIN := "res://scenes/main.tscn"
const MAIN_MENU := "res://scenes/ui/main_menu/main_menu.tscn"
const CHEF_SELECTION := (
	"res://scenes/ui/chef_selection_screen/chef_selection_screen.tscn"
)
const COLLECTION := "res://scenes/ui/collection/collection.tscn"
const STATS := "res://scenes/ui/stats/stats.tscn"
const DEVELOPER_MENU := "res://scenes/ui/developer_menu/developer_menu.tscn"
const UI_SANDBOX := "res://scenes/debug/ui_sandbox.tscn"
