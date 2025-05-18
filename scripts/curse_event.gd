class_name CurseEvent
extends Control

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var curse_data: CurseData

@onready var curse_panel: Panel = $HBoxContainer/CursePanel
@onready var curse_button: TextureButton = $HBoxContainer/CurseButton

func _on_curse_button_pressed() -> void:
	curse_panel.show()

func _on_close_button_pressed() -> void:
	curse_panel.hide()
