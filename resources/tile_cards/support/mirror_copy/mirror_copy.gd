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

	# Copy even Overdrive. Triggerability is inherited separately so others cannot retrigger this copy.
	var copied := opposite.active_tile_card
	if copied == null or not tile.map.is_tile_card_active(opposite):
		failed_tile_card_text(tile)
		return

	_is_resolving_copy = true
	copied._activation_output_scale = _activation_output_scale
	# Copied retriggers resolve from this hex. TileCard skips queuing this host so Break Glass cannot loop.
	copied._on_activate_tile_card(tile)
	copied._activation_output_scale = 1.0
	_is_resolving_copy = false


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_opposite_tile(hover_tile)


## When facing Overdrive, this copy also refuses queued triggers from other cards.
func can_be_triggered_by_other_card(tile: Hex = null) -> bool:
	if not super.can_be_triggered_by_other_card(tile):
		return false
	var copied := _copied_card_on_tile(tile)
	if copied == null:
		return true
	return not copied.single_activation_per_turn


func _copied_card_on_tile(tile: Hex) -> TileCard:
	if tile == null:
		return null
	var opposite := _get_opposite_hex(tile)
	if opposite == null or opposite == tile:
		return null
	return opposite.active_tile_card
