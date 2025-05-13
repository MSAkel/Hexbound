class_name TerrainTileUI
extends Panel

var hex: Hex = null

@onready var terrainLabel = $TerrianLabel
@onready var production_1_text = $ProductionText1
@onready var production_2_text = $ProductionText2
@onready var terrain_background_image = $BackgroundImage
@onready var resource_1_icon = $ResourceIcon1
@onready var resource_2_icon = $ResourceIcon2
@onready var building_1_icon = $BuildingIcon1
@onready var rune_icon = $RuneIcon


func _ready() -> void:
	pass

func _set_hex(h: Hex) -> void:
	hex = h
	resource_1_icon.texture = h.resource_1.icon
	resource_2_icon.texture = h.resource_2.icon
	
	show()

func _on_button_pressed() -> void:
	hide()
