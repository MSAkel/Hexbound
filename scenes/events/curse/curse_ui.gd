class_name CurseUI
extends Control

@onready var curse_panel: Panel = $Container/CursePanel
@onready var curse_button: TextureButton = $Container/CurseButton

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var curse: Curse = null

func _on_curse_button_pressed() -> void:
	curse_panel.show()

func _on_close_button_pressed() -> void:
	curse_panel.hide()
