# Handles the placement of cards on the hex tile map
class_name CardPlacementHandler
extends Node

# Reference to the tile map
var tile_map: HexTileMap

# Track if a card is being dragged
var is_card_dragging: bool = false
# Track the last tile we showed the overlay on
var last_hovered_tile: Vector2i = Vector2i(-1, -1)
# Reference to the card being dragged
var dragged_card: CardUI = null

func _ready() -> void:
	# Connect to card drag signals
	Events.card_drag_started.connect(_on_card_drag_started)
	Events.card_drag_ended.connect(_on_card_drag_ended)

func _input(event: InputEvent) -> void:
	if is_card_dragging:
		if event is InputEventMouseButton and not event.pressed:
			# Handle right click cancellation first
			if event.button_index == MOUSE_BUTTON_RIGHT:
				_clear_overlays()
				_reset_state()
				return
				
			# Handle left click placement
			if event.button_index == MOUSE_BUTTON_LEFT:
				_handle_card_placement()
		
		# Update highlighting on mouse motion when dragging
		if is_card_dragging and event is InputEventMouseMotion:
			_update_card_drag_highlight()

func _on_card_drag_started(card: CardUI) -> void:
	is_card_dragging = true
	dragged_card = card

func _on_card_drag_ended() -> void:
	is_card_dragging = false
	_clear_overlays()
	_reset_state()

func _handle_card_placement() -> void:
	if dragged_card == null:
		return
	
	# Use card center position for placement consistency
	var card_center_screen: Vector2 = dragged_card.global_position + dragged_card.size / 2.0
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	
	var card_center_world: Vector2
	if camera:
		var mouse_screen: Vector2 = viewport.get_mouse_position()
		var mouse_world: Vector2 = camera.get_global_mouse_position()
		var offset_screen: Vector2 = card_center_screen - mouse_screen
		var offset_world: Vector2 = offset_screen / camera.zoom
		card_center_world = mouse_world + offset_world
	else:
		card_center_world = card_center_screen
	
	var dragged_over_map_coords: Vector2i = tile_map.base_layer.local_to_map(tile_map.to_local(card_center_world))
	var placement_successful: bool = false
	
	if tile_map.is_in_map(dragged_over_map_coords):
		var h: Hex = tile_map.map_data[dragged_over_map_coords]
		if h.active_rune == null:
			h.place_rune(dragged_card.card)
			dragged_card.queue_free()
			placement_successful = true
		
		# If placement failed, return card to hand
		if not placement_successful:
			if dragged_card.card_state_machine:
				dragged_card.card_state_machine.transition_to_state(CardState.State.BASE)
	else:
		# Clicked outside map, return card to hand
		if dragged_card.card_state_machine:
			dragged_card.card_state_machine.transition_to_state(CardState.State.BASE)
	
	_reset_state()
	_clear_overlays()

func _update_card_drag_highlight() -> void:
	if dragged_card == null:
		return
	
	# Get the card's center position in screen/viewport coordinates
	var card_center_screen: Vector2 = dragged_card.global_position + dragged_card.size / 2.0
	
	# Convert screen coordinates to world coordinates
	var viewport: Viewport = get_viewport()
	var camera: Camera2D = viewport.get_camera_2d()
	
	var card_center_world: Vector2
	if camera:
		var mouse_screen: Vector2 = viewport.get_mouse_position()
		var mouse_world: Vector2 = camera.get_global_mouse_position()
		var offset_screen: Vector2 = card_center_screen - mouse_screen
		var offset_world: Vector2 = offset_screen / camera.zoom
		card_center_world = mouse_world + offset_world
	else:
		card_center_world = card_center_screen
	
	# Convert world position to map coordinates
	var map_coords: Vector2i = tile_map.base_layer.local_to_map(tile_map.to_local(card_center_world))
	
	# Clear overlay from previous tile if we've moved to a new tile
	if last_hovered_tile != map_coords:
		tile_map.card_drop_overlay_layer.set_cell(last_hovered_tile, -1)
		tile_map.card_drop_overlay_layer.modulate = Color.WHITE
		last_hovered_tile = map_coords
	
	if tile_map.is_in_map(map_coords):
		var h: Hex = tile_map.map_data[map_coords]
		var is_valid: bool = h.active_rune == null
		
		if is_valid:
			tile_map.card_drop_overlay_layer.set_cell(map_coords, 0, Vector2i(0,0))
			tile_map.card_drop_overlay_layer.modulate = Color.WHITE
		else:
			# Show red overlay for invalid placement
			tile_map.card_drop_overlay_layer.set_cell(map_coords, 0, Vector2i(0,0))
			tile_map.card_drop_overlay_layer.modulate = Color.RED
	else:
		# Clear overlay when not hovering over valid tile
		tile_map.card_drop_overlay_layer.set_cell(map_coords, -1)
		tile_map.card_drop_overlay_layer.modulate = Color.WHITE

func _clear_overlays() -> void:
	for coords in tile_map.map_data:
		tile_map.card_drop_overlay_layer.set_cell(coords, -1)
	tile_map.card_drop_overlay_layer.modulate = Color.WHITE

func _reset_state() -> void:
	last_hovered_tile = Vector2i(-1, -1)
	dragged_card = null
	is_card_dragging = false
