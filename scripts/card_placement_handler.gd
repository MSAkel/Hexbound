# Handles rune card selection and placement on the hex tile map.
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

const PREVIEW_ICON_SIZE := 200.0
const VALID_PREVIEW_COLOR := Color(1.0, 1.0, 1.0, 0.55)
const INVALID_PREVIEW_COLOR := Color(1.0, 0.35, 0.35, 0.45)


func _ready() -> void:
	Events.card_drag_started.connect(_on_card_selected)
	Events.card_drag_ended.connect(_on_card_deselected)
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
		var tex_size := icon.get_size()
		var scale_factor := PREVIEW_ICON_SIZE / maxf(tex_size.x, tex_size.y)
		_rune_preview.scale = Vector2(scale_factor, scale_factor)


func _update_rune_preview() -> void:
	if selected_card == null:
		return
	
	var map_coords := _get_mouse_map_coords()
	last_hovered_tile = map_coords
	
	if tile_map.is_in_map(map_coords):
		var hex: Hex = tile_map.map_data[map_coords]
		var tile_center: Vector2 = tile_map.base_layer.map_to_local(map_coords)
		_rune_preview.global_position = tile_map.to_global(tile_center)
		_rune_preview.modulate = VALID_PREVIEW_COLOR if _can_place_on_hex(hex) else INVALID_PREVIEW_COLOR
		_rune_preview.visible = true
	else:
		_rune_preview.visible = false


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
	if not _can_place_on_hex(hex):
		return
	
	if selected_card.card.type == Rune.RuneType.MODIFIER:
		selected_card.card.apply_on_placement(hex)
	else:
		hex.place_rune(selected_card.card)
	Events.card_played.emit(selected_card)
	AudioManager.play_sfx(UI_SOUNDS.GROUND_IMPACT)
	
	var card_to_remove := selected_card
	_clear_preview()
	_reset_state()
	card_to_remove.queue_free()


func _clear_preview() -> void:
	_rune_preview.visible = false
	last_hovered_tile = Vector2i(-1, -1)
	_clear_drop_overlay()


func _clear_drop_overlay() -> void:
	for coords in tile_map.map_data:
		tile_map.card_drop_overlay_layer.set_cell(coords, -1)
	tile_map.card_drop_overlay_layer.modulate = Color.WHITE


func _reset_state() -> void:
	selected_card = null
	is_card_selected = false


# Modifiers attach to occupied tiles; all other runes require an empty tile.
func _can_place_on_hex(hex: Hex) -> bool:
	if selected_card == null or selected_card.card == null:
		return false
	
	if selected_card.card.type == Rune.RuneType.MODIFIER:
		return hex.active_rune != null
	
	return hex.active_rune == null
