class_name RuinsUI
extends Control

@onready var description_panel: Panel = $Container/DescriptionPanel
@onready var ruins_name: Label = $Container/DescriptionPanel/MarginContainer/VBoxContainer/RuinsName
@onready var description: Label = $Container/DescriptionPanel/MarginContainer/VBoxContainer/Description
@onready var explore_button: Button = $Container/DescriptionPanel/MarginContainer/VBoxContainer/ExploreButton
@onready var ruins_button: TextureButton = $Container/RuinsButton

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var ruins: Ruins = null

func _on_ruins_button_pressed() -> void:
	description_panel.show()

func _on_close_button_pressed() -> void:
	description_panel.hide()

# Deducts the gold cost and sets the ruins as complete. This should open a new panel displaying the results
func _on_explore_button_pressed() -> void:
	GameManager.gold -= ruins.gold_cost
