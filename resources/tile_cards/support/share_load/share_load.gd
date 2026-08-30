extends TileCard
## Relay 45% of this segment's Energy pile and 20% of its bonus Mult to the next segment.

const ENERGY_RELAY_FRACTION := 0.45
const MULT_RELAY_FRACTION := 0.2


func _on_activate_tile_card(tile: Hex) -> void:
	var next_segment_index := _get_next_segment_index(tile)
	if next_segment_index < 0:
		failed_tile_card_text(tile)
		return
	var energy_relayed := int(round(float(_get_segment_turn_score(tile)) * ENERGY_RELAY_FRACTION))
	# Empty-segment Mult stays 1.0. Relay a slice of bonus Mult, not the implicit 1.0 base.
	var mult_bonus := maxf(0.0, _get_segment_turn_multiplier(tile) - 1.0)
	var mult_relayed := mult_bonus * MULT_RELAY_FRACTION
	if energy_relayed <= 0 and mult_relayed <= 0.0:
		failed_tile_card_text(tile)
		return
	if energy_relayed > 0:
		add_score_to_segment(tile, next_segment_index, energy_relayed)
	if mult_relayed > 0.0:
		add_multiplier_to_segment(tile, next_segment_index, mult_relayed)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_next_segment(hover_tile)
