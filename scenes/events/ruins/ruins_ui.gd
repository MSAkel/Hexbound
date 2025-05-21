class_name RuinsUI
extends Control

@onready var ruins_name: Label = $Container/DescriptionPanel/VBoxContainer/RuinsName
@onready var icon: TextureRect = $Container/DescriptionPanel/VBoxContainer/Icon
@onready var description: Label = $Container/DescriptionPanel/VBoxContainer/Description
@onready var explore_button: Button = $Container/DescriptionPanel/VBoxContainer/ExploreButton

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var ruins: Ruins

func _ready() -> void:
	pass

# displays the ruins description panel
func _on_ruins_button_pressed() -> void:
	pass # Replace with function body.


# closes the ruins description panel
func _on_close_button_pressed() -> void:
	pass # Replace with function body.

# Deducts the gold cost and sets the ruins as complete. This should open a new panel displaying the results
func _on_explore_button_pressed() -> void:
	pass # Replace with function body.
