class_name TerrainTileUI
extends Control

@onready var terrian_label: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/TerrianLabel
@onready var terrian_description: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/TerrianDescription
@onready var corruption_level_label: Label = $PanelContainer/VBoxContainer/TileDetailsContainer/VBoxContainer/CorruptionLevelLabel

# Rune section
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
	_set_rune_information()
	corruption_level_label.text = "Corruption Level: " + str(hex.corruption_level)
	show()

func _set_tile_information() -> void:
	terrian_label.text = "Hex"
	terrian_description.text = "An empty map hex."

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


func _on_toggle_rune_button_pressed() -> void:
	if hex.active_rune.is_active:
		hex.active_rune.is_active = false
		toggle_rune_button.text = "Enable"
	else:
		hex.active_rune.is_active = true
		toggle_rune_button.text = "Disable"
