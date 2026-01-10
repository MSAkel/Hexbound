class_name TerrainTileUI
extends Control

@onready var terrian_label: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/TerrianLabel
@onready var terrian_description: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/TerrianDescription
@onready var corruption_level_label: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/CorruptionLevelLabel

#Building section
@onready var building_panel: Panel = $PanelContainer/VBoxContainer/BuildingPanel
@onready var building_icon: TextureRect = $PanelContainer/VBoxContainer/BuildingPanel/BuildingPanelContainer/BuildingHBox/BuildingIconPanel/BuildingIcon
@onready var building_name_label: Label = $PanelContainer/VBoxContainer/BuildingPanel/BuildingPanelContainer/BuildingHBox/BuildingVBox/BuildingNameLabel
@onready var building_description_label: Label = $PanelContainer/VBoxContainer/BuildingPanel/BuildingPanelContainer/BuildingHBox/BuildingVBox/BuildingDescriptionLabel
@onready var building_prodution_label: Label = $PanelContainer/VBoxContainer/BuildingPanel/BuildingPanelContainer/BuildingHBox/BuildingVBox/BuildingProdutionLabel
@onready var destruct_building_button: Button = $PanelContainer/VBoxContainer/BuildingPanel/BuildingPanelContainer/BuildingHBox/BuildingVBox/DestructBuildingButton

#Rune section
@onready var rune_panel: Panel = $PanelContainer/VBoxContainer/RunePanel
@onready var rune_icon: TextureRect = $PanelContainer/VBoxContainer/RunePanel/RunePanelContainer/RuneHBox/RuneIconPanel/RuneIcon
@onready var rune_name_label: Label = $PanelContainer/VBoxContainer/RunePanel/RunePanelContainer/RuneHBox/RuneVBox/RuneNameLabel
@onready var rune_description_label: Label = $PanelContainer/VBoxContainer/RunePanel/RunePanelContainer/RuneHBox/RuneVBox/RuneDescriptionLabel
@onready var remove_rune_button: Button = $PanelContainer/VBoxContainer/RunePanel/RunePanelContainer/RuneHBox/RuneVBox/RemoveRuneButton
@onready var toggle_rune_button: Button = $PanelContainer/VBoxContainer/RunePanel/RunePanelContainer/RuneHBox/RuneVBox/ToggleRuneButton

var hex: Hex = null
var selected_rune: Rune = null

func _ready() -> void:
	pass

func set_hex(h: Hex) -> void:
	hex = h
	_set_tile_information()
	_set_building_information()
	_set_rune_information()
	corruption_level_label.text = "Corruption Level: " + str(hex.corruption_level)
	show()

func _set_tile_information() -> void:
	# Check the type of terrain then set the label and description for that terrain type
	match hex.terrain_type:
		Hex.TerrainType.FIELDS:
			terrian_label.text = "Fields"
			terrian_description.text = "Farms have a 25% chance to yield +1 food."
		Hex.TerrainType.FOREST:
			terrian_label.text = "Forest"
			terrian_description.text = "Lumber Camps have a 25% chance to yield +1 wood."
		Hex.TerrainType.MOUNTAIN:
			terrian_label.text = "Mountain"
			terrian_description.text = "Mines can be built on mountains. Quarries have a 25% chance to yield +1 stone."
		Hex.TerrainType.SNOW:
			terrian_label.text = "Snow"
			terrian_description.text = "Snow"
		Hex.TerrainType.SWAMP:
			terrian_label.text = "Swamp"
			terrian_description.text = "Swamps."
		Hex.TerrainType.WATER:
			terrian_label.text = "Water"
			terrian_description.text = "Water"
		_:
			terrian_label.text = "Unknown"
			terrian_description.text = "Unknown terrain type."

func _set_building_information() -> void:
	if hex.active_building != null:
		building_icon.texture = hex.active_building.icon
		building_name_label.text = hex.active_building.name
		building_description_label.text = hex.active_building.description
		for good in hex.active_building.generated_goods:
			if hex.active_building.generated_goods[good] > 0:
				building_prodution_label.text += "%s: %s\n" % [good, hex.active_building.generated_goods[good]]

		
		
		building_description_label.show()
		building_prodution_label.show()
	else:
		building_icon.texture = null
		building_name_label.text = "No building"
		building_description_label.hide()
		building_prodution_label.hide()


func _set_rune_information() -> void:
	if hex.active_rune != null:
		rune_icon.texture = hex.active_rune.icon
		rune_name_label.text = hex.active_rune.name
		rune_description_label.text = hex.active_rune.description
		rune_description_label.show()
		toggle_rune_button.show()
	else:
		rune_icon.texture = null
		rune_name_label.text = "No rune"
		rune_description_label.hide()
		toggle_rune_button.hide()

func _on_close_button_pressed() -> void:
	hide()


func _on_destruct_building_button_pressed() -> void:
	pass


func _on_toggle_rune_button_pressed() -> void:
	if hex.active_rune.is_active:
		hex.active_rune.is_active = false
		toggle_rune_button.text = "Enable"
	else:
		hex.active_rune.is_active = true
		toggle_rune_button.text = "Disable"
