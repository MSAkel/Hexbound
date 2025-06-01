class_name TerrainTileUI
extends Control

var hex: Hex = null
var selected_rune: Rune = null

@onready var terrainLabel = $TerrianLabel
#@onready var production_1_text = $ProductionText1
#@onready var production_2_text = $ProductionText2
@onready var terrain_background_image = $BackgroundImage
#@onready var mineral_1_icon = $MineralIcon1
#@onready var mineral_2_icon = $MineralIcon2
@onready var rune_icon: TextureRect = $Rune/ActiveRuneContainer/RuneIcon
@onready var rune_list_grid: GridContainer = $Rune/RunesListContainer/RuneListGrid
@onready var rune_description: Label = $Rune/RunesListContainer/RuneDescription
@onready var rune_requirements: Label = $Rune/RunesListContainer/RuneRequirements
@onready var insert_rune_button: Button = $Rune/RunesListContainer/InsertRuneButton
@onready var remove_rune_button: Button = $Rune/ActiveRuneContainer/RemoveRuneButton

const RUNE_UI = preload("res://scenes/ui/runes/rune_ui.tscn")

func _ready() -> void:
	populate_rune_list(GameManager.runes_pool)
	if selected_rune == null:
		insert_rune_button.disabled = true

func set_hex(h: Hex) -> void:
	hex = h
	#print(h)
	#mineral_1_icon.texture = h.minerals[0].icon
	#mineral_2_icon.texture = h.minerals[1].icon
	
	# Reset rune UI state
	selected_rune = null
	insert_rune_button.disabled = true
	remove_rune_button.hide()
	remove_rune_button.disabled = true
	rune_requirements.text = ""
	rune_requirements.remove_theme_color_override("font_color")
	
	# Update rune UI based on hex's active rune
	if h.active_rune:
		selected_rune = h.active_rune
		rune_icon.texture = h.active_rune.icon
		rune_requirements.text = h.active_rune.get_essence_requirements_text()
		remove_rune_button.show()
		remove_rune_button.disabled = false
	else:
		rune_icon.texture = null
	
	show()

func populate_rune_list(runes: Array[Rune]) -> void:
	for rune in runes:
		var rune_button: RuneUI = RUNE_UI.instantiate() as RuneUI
		rune_button.rune = rune
		rune_button.icon = rune.icon
		rune_button.rune_selected.connect(on_rune_selected)
		rune_list_grid.add_child(rune_button)

func on_rune_selected(rune: Rune) -> void:
	selected_rune = rune
	rune_requirements.text = rune.get_essence_requirements_text()
	
	if rune.can_activate():
		insert_rune_button.disabled = false
		rune_requirements.add_theme_color_override("font_color", Color.GREEN)
	else:
		insert_rune_button.disabled = true
		rune_requirements.add_theme_color_override("font_color", Color.RED)

func _on_insert_rune_button_pressed() -> void:
	# if hex.active_rune:
	# 	GameManager.fire_essence += hex.active_rune.fire_essence_cost
	# 	GameManager.nature_essence += hex.active_rune.nature_essence_cost
	# 	GameManager.frost_essence += hex.active_rune.frost_essence_cost
	# 	GameManager.storm_essence += hex.active_rune.storm_essence_cost
		
	hex.active_rune = selected_rune
	rune_icon.texture = selected_rune.icon
	# Deduct essence costs
	# GameManager.fire_essence -= selected_rune.fire_essence_cost
	# GameManager.nature_essence -= selected_rune.nature_essence_cost
	# GameManager.frost_essence -= selected_rune.frost_essence_cost
	# GameManager.storm_essence -= selected_rune.storm_essence_cost
	
	remove_rune_button.show()
	remove_rune_button.disabled = false


func _on_remove_rune_button_pressed() -> void:
	# GameManager.fire_essence += hex.active_rune.fire_essence_cost
	# GameManager.nature_essence += hex.active_rune.nature_essence_cost
	# GameManager.frost_essence += hex.active_rune.frost_essence_cost
	# GameManager.storm_essence += hex.active_rune.storm_essence_cost
	
	hex.active_rune = null
	rune_icon.texture = null
	remove_rune_button.hide()
	remove_rune_button.disabled = true

func _on_button_pressed() -> void:
	hide()
