class_name RuinsUI
extends Control

@onready var ruins_name: Label = $Container/DescriptionPanel/VBoxContainer/RuinsName
@onready var icon: TextureRect = $Container/DescriptionPanel/VBoxContainer/Icon
@onready var description: Label = $Container/DescriptionPanel/VBoxContainer/Description
@onready var explore_button: Button = $Container/DescriptionPanel/VBoxContainer/ExploreButton
@onready var description_panel: Panel = $Container/DescriptionPanel

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var ruins: Ruins

func _ready() -> void:
	pass

func _on_ruins_icon_button_pressed() -> void:
	description_panel.show()

func _on_close_button_pressed() -> void:
	description_panel.hide()

# Deducts the gold cost and sets the ruins as complete. This should open a new panel displaying the results
func _on_explore_button_pressed() -> void:
	pass # Replace with function body.
