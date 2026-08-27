extends TileCard

# Triggers the effect of the next rune twice. works on support runes
func _init() -> void:
	single_activation_per_turn = true

func _on_activate_tile_card(tile: Hex) -> void:
	var next_rune: TileCard = _get_next_tile_card_in_trigger_order(tile)
	if next_rune == null:
		failed_tile_card_text(tile)
		return

	_try_queue_tile_card_triggers(tile, [next_rune, next_rune])


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_rune := _get_next_tile_card_in_trigger_order(hover_tile)
	if next_rune == null:
		return []
	return _coords_for_placed_tile_cards(hover_tile, [next_rune])
