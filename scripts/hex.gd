class_name Hex
extends RefCounted

## One map cell. RefCounted so it does not leak when dropped from map_data.
## dispose() must run before the dict is cleared, because this object holds the map Node.

const RUNE_UI: PackedScene = preload("res://scenes/ui/runes/rune_ui.tscn")

var _coordinates: Vector2i = Vector2i(0, 0)
## The TileCard currently occupying this hex.
var active_tile_card: TileCard = null
var rune_ui: RuneUI = null
# Permanently disabled by difficulty level 5. The tile cannot be used for the run.
var is_disabled_by_difficulty: bool = false

var map: HexTileMap
var items_grid: Control
# Optional event tint layered on top of the normal active/inactive state.
var _event_rune_modulate: Color = Color.WHITE

# Match the dashed hex art size so overlays sit on the tile texture.
const HEX_TILE_SIZE := Vector2(HexTileMap.HEX_TEXTURE_SIZE)
const HEX_TILE_HALF := HEX_TILE_SIZE / 2
# Square rune controls. Centered on the hex because the icons still have side padding.
const HEX_RUNE_SIZE := HexTileMap.HEX_RUNE_SIZE
const RUNE_INACTIVE_MODULATE := Color(0.35, 0.35, 0.42, 0.78)
const RUNE_FADED_SECTOR_MODULATE := Color(0.58, 0.46, 0.34, 0.9)

var coordinates: Vector2i:
	get:
		return _coordinates

func _init(coords: Vector2i) -> void:
	_coordinates = coords


func setup(map_ref: Node2D) -> void:
	map = map_ref
	# Container sized to one hex; map_to_local returns the tile center
	items_grid = Control.new()
	items_grid.custom_minimum_size = HEX_TILE_SIZE
	items_grid.size = HEX_TILE_SIZE
	items_grid.position = map.base_layer.map_to_local(coordinates) - HEX_TILE_HALF
	map.add_child(items_grid)


## Drops the map-side Control so regenerate and scene exit do not leave orphan UI.
func dispose() -> void:
	if items_grid != null and is_instance_valid(items_grid):
		items_grid.queue_free()
	items_grid = null
	rune_ui = null
	active_tile_card = null
	map = null


## False after dispose, or before setup, when this hex should not drive animations.
func is_on_map() -> bool:
	return map != null and items_grid != null and is_instance_valid(items_grid)


func _fit_rune_ui(rune_ui_node: RuneUI) -> void:
	rune_ui_node.custom_minimum_size = HEX_RUNE_SIZE
	rune_ui_node.size = HEX_RUNE_SIZE
	rune_ui_node.position = (HEX_TILE_SIZE - HEX_RUNE_SIZE) * 0.5


## True when this hex cannot receive a new card. Difficulty locks and Sealed Hexes both count.
func is_placement_blocked() -> bool:
	if is_disabled_by_difficulty:
		return true
	return EventManager.is_hex_sealed(coordinates)


func place_tile_card(rune: TileCard, animate: bool = true) -> void:
	# Prevent placing a rune if one already exists or the tile is locked for placement.
	if active_tile_card != null or is_placement_blocked():
		return
	
	# Each tile needs its own rune instance. hand/pool cards often share one .tres reference.
	active_tile_card = rune.duplicate(true)
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	rune_ui = new_rune_instance
	new_rune_instance.map = map
	new_rune_instance.tile = self
	new_rune_instance.center_coordinates = coordinates
	_fit_rune_ui(new_rune_instance)
	# Add first so setup is not deferred. Deferred setup can run after the hex is disposed.
	items_grid.add_child(new_rune_instance)
	new_rune_instance.setup(active_tile_card)
	if animate and not GameManager.skip_presentation:
		new_rune_instance.play_placement_animation()
	_apply_display_mode()
	refresh_tile_card_visual_state()
	if map != null:
		map.refresh_dashed_outlines()


# Restore a placed rune from a save file without duplicating the resource again.
func restore_placed_tile_card(rune: TileCard) -> void:
	if active_tile_card != null or is_disabled_by_difficulty:
		return

	active_tile_card = rune
	var new_rune_instance: RuneUI = RUNE_UI.instantiate()
	rune_ui = new_rune_instance
	new_rune_instance.map = map
	new_rune_instance.tile = self
	new_rune_instance.center_coordinates = coordinates
	new_rune_instance.setup(rune)
	_fit_rune_ui(new_rune_instance)
	items_grid.add_child(new_rune_instance)
	_apply_display_mode()
	refresh_tile_card_visual_state()
	if map != null:
		map.refresh_dashed_outlines()


func _apply_display_mode() -> void:
	var has_rune := rune_ui != null and active_tile_card != null
	if rune_ui != null:
		rune_ui.visible = has_rune


func refresh_tile_card_visual_state() -> void:
	if rune_ui == null or active_tile_card == null:
		return

	var target_modulate := Color.WHITE
	if not active_tile_card.is_active:
		target_modulate = RUNE_INACTIVE_MODULATE
	elif _event_rune_modulate != Color.WHITE:
		target_modulate = _event_rune_modulate

	rune_ui.apply_resting_modulate(target_modulate)
	rune_ui.refresh_output_chip(active_tile_card)
	rune_ui.refresh_potion_badges(active_tile_card, coordinates)
	# Restore overcharge sparks after load or chip refresh. The strike itself is not replayed.
	if active_tile_card.is_empowered:
		rune_ui.start_empower_sparks()
	else:
		rune_ui.stop_empower_sparks()


func set_tile_card_event_modulate(modulate: Color) -> void:
	_event_rune_modulate = modulate
	refresh_tile_card_visual_state()


func clear_tile_card_event_modulate() -> void:
	_event_rune_modulate = Color.WHITE
	refresh_tile_card_visual_state()


# Clear the placed rune from this tile and remove its map UI.
func remove_tile_card() -> void:
	if active_tile_card == null:
		return
	
	active_tile_card = null
	_event_rune_modulate = Color.WHITE
	if rune_ui != null:
		rune_ui.queue_free()
		rune_ui = null
	_apply_display_mode()
	if map != null:
		map.refresh_dashed_outlines()


# Play the rune trigger animation without applying the effect.
func play_tile_card_activation_animation() -> void:
	if active_tile_card == null or rune_ui == null:
		return
	
	# Only animate active runes so inactive runes do not look triggered.
	if active_tile_card.is_active:
		rune_ui.play_activation_animation()


# Chained activation from another rune's trigger ability.
func play_chained_tile_card_activation_animation() -> void:
	if active_tile_card == null or rune_ui == null:
		return

	if active_tile_card.is_active:
		rune_ui.play_chained_activation_animation()


# Gold highlight flash used during the post-turn segment result reveal.
func play_segment_result_animation() -> void:
	if rune_ui == null:
		return
	rune_ui.play_segment_result_animation()


func apply_tile_card_activation(activation_scale: float = 1.0) -> void:
	if active_tile_card == null:
		return
	
	active_tile_card.activate_tile_card(self, activation_scale)
	refresh_tile_card_visual_state()


func start_empower_sparks() -> void:
	if rune_ui == null:
		return
	rune_ui.start_empower_sparks()


func stop_empower_sparks() -> void:
	if rune_ui == null:
		return
	rune_ui.stop_empower_sparks()


func start_trigger_link_flash() -> void:
	if rune_ui == null:
		return
	rune_ui.start_trigger_link_flash()


func stop_trigger_link_flash() -> void:
	if rune_ui == null:
		return
	rune_ui.stop_trigger_link_flash()
