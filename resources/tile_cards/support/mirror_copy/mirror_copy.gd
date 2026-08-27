extends TileCard
## Copies the ability of whichever card currently occupies the opposite map tile.

# Prevents two facing Mirror Copies from recursively copying each other.
static var _is_resolving_copy: bool = false


func _on_activate_tile_card(tile: Hex) -> void:
	if _is_resolving_copy:
		return

	var opposite := _get_opposite_hex(tile)
	if opposite == null or opposite == tile:
		failed_tile_card_text(tile)
		return

	# Always read the live occupant. A later replacement on that tile is what gets copied.
	var copied := opposite.active_tile_card
	if copied == null or not tile.map.is_tile_card_triggerable(opposite):
		failed_tile_card_text(tile)
		return

	_is_resolving_copy = true
	copied._activation_output_scale = _activation_output_scale
	copied._on_activate_tile_card(tile)
	copied._activation_output_scale = 1.0
	_is_resolving_copy = false


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_opposite_tile(hover_tile)
