class_name TilePanel
extends Control

@onready var active_tile_modifier: Label = $PanelContainer/MarginContainer/VBoxContainer/TileDetailsContainer/ActiveTileModifier

@onready var rune_icon: TextureRect = $PanelContainer/MarginContainer/VBoxContainer/RunePanelContainer/RuneIconPanel/RuneIcon
@onready var rune_name: Label = $PanelContainer/MarginContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneName
@onready var rune_description: Label = $PanelContainer/MarginContainer/VBoxContainer/RunePanelContainer/RuneVBox/RuneDescription

@onready var remove_rune_button: Button = $PanelContainer/MarginContainer/VBoxContainer/RunePanelContainer/RuneVBox/HBoxContainer/RemoveRuneButton
@onready var toggle_rune_button: Button = $PanelContainer/MarginContainer/VBoxContainer/RunePanelContainer/RuneVBox/HBoxContainer/ToggleRuneButton

var hex: Hex = null
var selected_rune: Rune = null

func _ready() -> void:
	Events.turn_ended.connect(_on_turn_ended)

func set_hex(h: Hex) -> void:
	hex = h
	_set_tile_information()
	_set_rune_information()
	show()

func _set_tile_information() -> void:
	var lines: PackedStringArray = []

	if hex.segment_passive_modifier != null:
		lines.append(
			"Segment Passive: %s\n%s" % [
				hex.segment_passive_modifier.name,
				hex.segment_passive_modifier.description,
			]
		)

	if hex.tile_modifier != null:
		lines.append(
			"Tile Modifier: %s\n%s" % [
				hex.tile_modifier.name,
				hex.tile_modifier.description,
			]
		)

	if lines.is_empty():
		active_tile_modifier.text = "None"
	else:
		active_tile_modifier.text = "\n\n".join(lines)

func _set_rune_information() -> void:
	if hex.active_rune != null:
		rune_icon.texture = hex.active_rune.icon
		rune_name.text = hex.active_rune.name
		var description_lines: PackedStringArray = [hex.active_rune.description]
		if hex.active_rune.enhancement != null:
			description_lines.append(
				"Enhancement: %s\n%s" % [
					hex.active_rune.enhancement.name,
					hex.active_rune.enhancement.description,
				]
			)
		rune_description.text = "\n\n".join(description_lines)
		remove_rune_button.disabled = false
	else:
		rune_icon.texture = load("res://assets/tilesets/tile_dashed.png")
		rune_name.text = "No Rune"
		rune_description.text = ""
		remove_rune_button.disabled = true

func _on_close_button_pressed() -> void:
	hide()


func _on_toggle_rune_button_pressed() -> void:
	if hex.active_rune.is_active:
		hex.active_rune.is_active = false
		toggle_rune_button.text = "Enable"
	else:
		hex.active_rune.is_active = true
		toggle_rune_button.text = "Disable"

func _on_turn_ended() -> void:
	hide()
