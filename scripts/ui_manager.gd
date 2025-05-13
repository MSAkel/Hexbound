extends Node

@onready var terrain_tile_ui: TerrainTileUI = $TerrainTileUi

func _ready() -> void:
	hide_all_panels()

func hide_all_panels():
	for child in get_children():
		if child is Panel:
			child.hide()

#func show_panel(panel: String):
	#pass

func  set_terrain_ui(h: Hex):
	pass
