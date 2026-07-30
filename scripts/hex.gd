class_name Hex
extends Node

# CURSED: Timed event. Unresolved = bad. Resolved = good.
# ENCAMPMENT: Occupoed by a camp. Can be resolved through bargain
# RUINS: ?
enum SpecialTileState { NONE, CURSED, ENCAMPMENT, RUINS }

# Special events UI
var CURSE_UI: PackedScene = preload("res://scenes/events/curse/curse_ui.tscn")
const RUINS_UI: PackedScene = preload("res://scenes/events/ruins/ruins_ui.tscn")
const RUNE_UI: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")

var curse: CurseUI
var ruins: RuinsUI

var _coordinates: Vector2i = Vector2i(0, 0)
var active_rune: Rune = null
var special_state: SpecialTileState = SpecialTileState.NONE
# var minerals: Array[MineralUI] = []

## Not implemented yet
var corruption_level: int = 0

# References to UI elements
# var mineral_ui_scene: PackedScene
var map: HexTileMap
var items_grid: GridContainer

# Match the dashed hex art size so runes align with the tile texture
const HEX_TILE_SIZE := Vector2(HexTileMap.HEX_TEXTURE_SIZE, HexTileMap.HEX_TEXTURE_SIZE)
const HEX_TILE_HALF := HEX_TILE_SIZE / 2

var coordinates: Vector2i:
	get:
		return _coordinates

func _init(coords: Vector2i) -> void:
	_coordinates = coords


func setup(map_ref: Node2D) -> void:
	map = map_ref
	# Container sized to one hex; map_to_local returns the tile center
	items_grid = GridContainer.new()
	items_grid.columns = 1
	items_grid.custom_minimum_size = HEX_TILE_SIZE
	items_grid.size = HEX_TILE_SIZE
	items_grid.position = map.base_layer.map_to_local(coordinates) - HEX_TILE_HALF
	items_grid.add_theme_constant_override("separation", 0)
	map.add_child(items_grid)


func place_rune(rune: Rune) -> void:
	# Prevent placing a rune if one already exists
	if active_rune != null:
		return
	
	active_rune = rune
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	new_rune_instance.map = map
	new_rune_instance.tile = self
	new_rune_instance.center_coordinates = coordinates

	new_rune_instance.setup(rune)
	
	# Fill the entire hex cell (256x256)
	new_rune_instance.custom_minimum_size = HEX_TILE_SIZE
	new_rune_instance.size = HEX_TILE_SIZE
	new_rune_instance.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	new_rune_instance.size_flags_vertical = Control.SIZE_EXPAND_FILL
	
	items_grid.add_child(new_rune_instance)
	_reposition_items()


# func apply_special_state() -> void:
# 	match special_state:
# 		SpecialTileState.CURSED:
# 			var curse_instance: CurseUI = CURSE_UI.instantiate()
# 			curse_instance.map = map
# 			curse_instance.tile = self
# 			curse_instance.center_coordinates = coordinates
# 			curse = curse_instance
			
# 			# Set size for the curse instance
# 			curse_instance.custom_minimum_size = Vector2(60, 60)
# 			curse_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
# 			curse_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
# 			# Add to grid instead of directly to map
# 			items_grid.add_child(curse_instance)
# 			_reposition_items()
# 		# SpecialTileState.ENCAMPMENT:
# 		# 	# TODO: Implement encampment logic
# 		# 	pass
# 		SpecialTileState.RUINS:
# 			var ruins_instance: RuinsUI = RUINS_UI.instantiate() as RuinsUI
# 			ruins_instance.map = map
# 			ruins_instance.tile = self
# 			ruins_instance.center_coordinates = coordinates
# 			ruins = ruins_instance
			
# 			# Set size for the ruins instance
# 			ruins_instance.custom_minimum_size = Vector2(60, 60)
# 			ruins_instance.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
# 			ruins_instance.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			
# 			# Add to grid instead of directly to map
# 			items_grid.add_child(ruins_instance)
# 			_reposition_items()

# Keep placed items aligned to the hex bounds
func _reposition_items() -> void:
	for item in items_grid.get_children():
		item.position = Vector2.ZERO
		item.size = HEX_TILE_SIZE


func trigger_rune_activation() -> void:
	active_rune.activate_rune(self)
