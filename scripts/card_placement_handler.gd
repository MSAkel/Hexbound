# Handles hand card selection and placement on the hex tile map.
class_name CardPlacementHandler
extends Node

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

# Reference to the tile map.
var tile_map: HexTileMap

# True while a hand card is selected for placement.
var is_card_selected: bool = false
# Backwards-compatible alias used by HexTileMap hover logic.
var is_card_dragging: bool:
	get:
		return is_card_selected

var selected_card: CardUI = null
var last_hovered_tile: Vector2i = Vector2i(-1, -1)
var _rune_preview: Sprite2D
# Prevents deselect cleanup when swapping from one selected card to another.
var _switching_selection: bool = false
# Tiles temporarily marked invalid while placing a restricted rune card.
var _restricted_invalid_coords: Array[Vector2i] = []
# Tile currently targeted for placement while hovering.
var _placement_target_coord: Vector2i = Vector2i(-1, -1)
# Tiles currently showing trigger-effect preview highlights.
var _effect_preview_coords: Array[Vector2i] = []

const VALID_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.7)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.35, 0.35, 0.45)


func _ready() -> void:
	EventBus.card_drag_started.connect(_on_card_selected)
	EventBus.card_drag_ended.connect(_on_card_deselected)
	_setup_rune_preview()


func _setup_rune_preview() -> void:
	_rune_preview = Sprite2D.new()
	_rune_preview.centered = true
	_rune_preview.visible = false
	_rune_preview.z_index = 5
	tile_map.add_child(_rune_preview)


func _unhandled_input(event: InputEvent) -> void:
	if not is_card_selected:
		return
	
	if event is InputEventMouseMotion:
		_update_rune_preview()
	
	if event is InputEventMouseButton and not event.pressed:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_deselect_card()
			get_viewport().set_input_as_handled()
			return
		
		if event.button_index == MOUSE_BUTTON_LEFT:
			_try_place_card()
			get_viewport().set_input_as_handled()
	
	if event.is_action_pressed("ui_cancel"):
		_deselect_card()
		get_viewport().set_input_as_handled()


func _on_card_selected(card: CardUI) -> void:
	if selected_card != null and selected_card != card:
		_switching_selection = true
		selected_card.card_state_machine.transition_to_state(CardState.State.BASE)
		_switching_selection = false
	
	is_card_selected = true
	selected_card = card
	_update_preview_texture()
	_update_placement_overlays()
	_update_rune_preview()


func _on_card_deselected() -> void:
	if _switching_selection:
		return
	_clear_preview()
	_reset_state()


func _deselect_card() -> void:
	if selected_card and selected_card.card_state_machine:
		selected_card.card_state_machine.transition_to_state(CardState.State.BASE)


func _update_preview_texture() -> void:
	if selected_card == null or selected_card.card == null:
		return
	
	var icon: Texture2D = selected_card.card.icon
	_rune_preview.texture = icon
	if icon:
		# Match the placed rune's hover size, slightly larger than the hex art.
		var tex_size := icon.get_size()
		var preview_pixel_size := float(HexTileMap.HEX_TEXTURE_SIZE) * RuneUI.PLACEMENT_HOVER_SCALE
		var scale_factor := preview_pixel_size / maxf(tex_size.x, tex_size.y)
		_rune_preview.scale = Vector2(scale_factor, scale_factor)


func _update_rune_preview() -> void:
	if selected_card == null:
		return
	
	var map_coords := _get_mouse_map_coords()
	last_hovered_tile = map_coords
	
	var hex: Hex = tile_map.map_data.get(map_coords) if tile_map.is_in_map(map_coords) else null
	var over_valid_tile := hex != null \
		and tile_map.is_tile_interactable(map_coords) \
		and _can_place_on_hex(hex)
	# Dip the selected card while it covers fewer bottom tiles.
	selected_card.set_map_tile_hover_active(over_valid_tile)
	
	if over_valid_tile:
		var tile_center: Vector2 = tile_map.base_layer.map_to_local(map_coords)
		_rune_preview.global_position = tile_map.to_global(tile_center)
		_rune_preview.modulate = VALID_PREVIEW_COLOR
		_rune_preview.visible = true
		_update_hover_highlights(hex)
	else:
		_rune_preview.visible = false
		_clear_hover_highlights()


func _get_mouse_map_coords() -> Vector2i:
	return tile_map.base_layer.local_to_map(
		tile_map.to_local(tile_map.get_global_mouse_position())
	)


func _try_place_card() -> void:
	if selected_card == null:
		return
	
	var map_coords := _get_mouse_map_coords()
	
	if not tile_map.is_in_map(map_coords):
		_deselect_card()
		return
	
	var hex: Hex = tile_map.map_data[map_coords]
	if not tile_map.is_tile_interactable(map_coords):
		return
	if not _can_place_on_hex(hex):
		return

	# Hide the hover sprite so the placed rune can take over the same oversized pose.
	_rune_preview.visible = false
	selected_card.card.play_on(hex)
	EventBus.card_played.emit(selected_card)
	AudioManager.play_sfx(UI_SOUNDS.GROUND_IMPACT)
	
	var card_to_remove := selected_card
	_clear_preview()
	_reset_state()
	card_to_remove.queue_free()


func _clear_preview() -> void:
	if selected_card != null:
		selected_card.set_map_tile_hover_active(false, false)
	_rune_preview.visible = false
	last_hovered_tile = Vector2i(-1, -1)
	_clear_placement_overlays()


func _clear_placement_overlays() -> void:
	_clear_hover_highlights()
	_clear_restriction_overlays()
	tile_map.rune_highlight_overlay_layer.modulate = Color.WHITE


func _clear_restriction_overlays() -> void:
	for coords: Vector2i in _restricted_invalid_coords:
		if tile_map.map_data[coords].is_disabled_by_difficulty:
			continue
		tile_map.disabled_tile_overlay_layer.set_cell(coords, -1)
	_restricted_invalid_coords.clear()


func _clear_hover_highlights() -> void:
	_clear_rune_highlights_at(_effect_preview_coords)
	_effect_preview_coords.clear()
	if _placement_target_coord != Vector2i(-1, -1):
		_clear_rune_highlight_at(_placement_target_coord)
		_placement_target_coord = Vector2i(-1, -1)


func _clear_rune_highlights_at(coords_list: Array[Vector2i]) -> void:
	for coords: Vector2i in coords_list:
		_clear_rune_highlight_at(coords)


func _clear_rune_highlight_at(coords: Vector2i) -> void:
	# Segment-row hover shares this layer, do not erase its tiles while that hover is active.
	if tile_map.has_hovered_segment_highlight_at(coords):
		return
	tile_map.rune_highlight_overlay_layer.set_cell(coords, -1)


## True when this handler currently stamps a placement/effect highlight on coords.
func is_highlighting_coord(coords: Vector2i) -> bool:
	return coords == _placement_target_coord or coords in _effect_preview_coords


func _stamp_rune_highlight(coords: Vector2i) -> void:
	tile_map.rune_highlight_overlay_layer.set_cell(
		coords,
		tile_map.RUNE_HIGHLIGHT_SOURCE_ID,
		tile_map.OVERLAY_TILE_ATLAS_COORDS
	)


func _reset_state() -> void:
	selected_card = null
	is_card_selected = false


# Disables invalid tiles for runes with placement restrictions.
func _update_placement_overlays() -> void:
	_clear_placement_overlays()
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null or not tile_card.has_placement_restriction():
		return
	
	for coords: Vector2i in tile_map.map_data:
		var hex: Hex = tile_map.map_data[coords]
		if not _is_placement_candidate(hex):
			continue
		
		if tile_card.can_place_on_tile(hex):
			continue
		
		_restricted_invalid_coords.append(coords)
		if not hex.is_disabled_by_difficulty:
			tile_map.disabled_tile_overlay_layer.set_cell(
				coords,
				tile_map.OVERLAY_TILE_SOURCE_ID,
				tile_map.OVERLAY_TILE_ATLAS_COORDS
			)


# Highlights the hovered placement tile and any tiles its effect would impact.
func _update_hover_highlights(hover_hex: Hex) -> void:
	_clear_hover_highlights()
	
	_placement_target_coord = hover_hex.coordinates
	_stamp_rune_highlight(_placement_target_coord)
	
	var tile_card := _get_selected_tile_card()
	if tile_card == null:
		return
	
	for coords: Vector2i in tile_card.get_trigger_preview_coords(hover_hex):
		if not tile_map.is_in_map(coords):
			continue
		if coords == _placement_target_coord:
			continue
		_stamp_rune_highlight(coords)
		_effect_preview_coords.append(coords)


func _get_selected_tile_card() -> TileCard:
	if selected_card == null or not (selected_card.card is TileCard):
		return null
	return selected_card.card as TileCard


# Tiles that can receive the currently selected card before restriction checks.
func _is_placement_candidate(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	return selected_card.card.is_placement_candidate(hex)


# Delegates occupancy, restrictions, and attach rules to the selected Card.
func _can_place_on_hex(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	return selected_card.card.can_play_on(hex)
