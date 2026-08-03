class_name Hex
extends Node

const RUNE_UI: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")


var _coordinates: Vector2i = Vector2i(0, 0)
var active_rune: Rune = null
var rune_ui: RuneUI = null
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
	
	# Each tile needs its own rune instance. hand/pool cards often share one .tres reference.
	active_rune = rune.duplicate(true)
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	rune_ui = new_rune_instance
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
	new_rune_instance.play_placement_animation()


# Clear the placed rune from this tile and remove its map UI.
func remove_rune() -> void:
	if active_rune == null:
		return
	
	active_rune = null
	if rune_ui != null:
		rune_ui.queue_free()
		rune_ui = null

# Keep placed items aligned to the hex bounds
func _reposition_items() -> void:
	for item in items_grid.get_children():
		item.position = Vector2.ZERO
		item.size = HEX_TILE_SIZE


# Play the rune trigger animation without applying the effect.
func play_rune_activation_animation() -> void:
	if active_rune == null or rune_ui == null:
		return
	
	# Only animate active runes so inactive runes do not look triggered.
	if active_rune.is_active:
		rune_ui.play_activation_animation()


func apply_rune_activation(score_multiplier: float = 1.0) -> void:
	if active_rune == null:
		return
	
	active_rune.activate_rune(self, score_multiplier)
