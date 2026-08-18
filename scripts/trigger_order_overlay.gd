class_name TriggerOrderOverlay
extends Node2D

# Runtime labels and segment-color fills for the order-segments map layout.
# Numbers cannot live on a TileMapLayer, so this stamps Control markers per hex.

const MARKER_SCENE := preload("res://scenes/ui/trigger_order_marker.tscn")

var _map: HexTileMap
var _built: bool = false


func setup(map: HexTileMap) -> void:
	_map = map
	visible = false


func set_active(active: bool) -> void:
	if active and not _built:
		rebuild()
	visible = active


func rebuild() -> void:
	# free() now so a second rebuild in the same frame cannot stack duplicates.
	for child in get_children():
		child.free()
	_built = false
	if _map == null:
		return

	var order := 1
	for coords: Vector2i in _map.get_coords_in_trigger_order():
		var marker: TriggerOrderMarker = MARKER_SCENE.instantiate()
		add_child(marker)
		# Same top-left origin as Hex.items_grid so the fill sits on the dashed hex.
		marker.position = _map.base_layer.map_to_local(coords) - Hex.HEX_TILE_HALF
		marker.setup(
			order,
			_map.is_first_tile_in_segment(coords),
			_map.is_last_tile_in_segment(coords)
		)
		order += 1
	_built = true
