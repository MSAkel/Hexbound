class_name TerrainTileUI
extends Control

var hex: Hex = null

@onready var terrainLabel = $TerrianLabel
@onready var production_1_text = $ProductionText1
@onready var production_2_text = $ProductionText2
@onready var terrain_background_image = $BackgroundImage
@onready var mineral_1_icon = $MineralIcon1
@onready var mineral_2_icon = $MineralIcon2
@onready var rune_icon: TextureRect = $Rune/ActiveRuneContainer/RuneIcon
@onready var explore_button: Button = $ExploreButton
@onready var rune_list_grid: GridContainer = $Rune/RuneListGrid
const RUNE_GUI = preload("res://scenes/ui/rune_gui.tscn")

func _ready() -> void:
	populate_rune_list(GameManager.available_runes)

func set_hex(h: Hex) -> void:
	hex = h
	mineral_1_icon.texture = h.minerals[0].mineral_data.icon
	mineral_2_icon.texture = h.minerals[1].mineral_data.icon
	show()

func _on_button_pressed() -> void:
	hide()

func _on_explore_button_pressed() -> void:
	# GameManager.explore_tile(hex)
	GameManager.tile_explored.emit(hex)
	explore_button.text = "Explored"

func populate_rune_list(runes: Array[RuneData]) -> void:
	for rune in runes:
		var rune_button := RUNE_GUI.instantiate() as RuneGui
		rune_button.rune = rune
		rune_button.icon = rune.icon
		rune_button.rune_selected.connect(on_rune_selected)
		rune_list_grid.add_child(rune_button)

func on_rune_selected(rune: RuneData) -> void:
	print("on_rune_selected")
	hex.active_rune = rune
	rune_icon.texture = rune.icon
