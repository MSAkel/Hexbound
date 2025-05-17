extends CanvasLayer

signal show_perks_choice_panel()
signal show_runes_panel()
signal show_building_choice_panel()

@onready var terrain_tile_ui: TerrainTileUI = $TerrainTileUi
@onready var top_panel_ui: TopPanelUi = $TopPanelUI

func _ready() -> void:
	hide_all_panels()

func hide_all_panels():
	for child in get_children():
		if child is Control and not child.is_in_group("main_ui"):
			child.hide()
