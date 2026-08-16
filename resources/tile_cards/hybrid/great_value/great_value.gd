extends TileCard

# Spends 1 gold to empower a random prod rune in its segment. can be triggered more than once
func _on_activate_tile_card(tile: Hex) -> void:
	if not GoldManager.can_afford(1):
		_create_floating_text(tile, "Insufficient gold")
		return

	GoldManager.remove(1)
	
	var prod_runes := _get_all_tile_cards_on_same_segment(tile, TileCardType.PRODUCER)
	if prod_runes.is_empty():
		_create_floating_text(tile, "No effect")
		return
	
	var target_rune : TileCard = prod_runes.pick_random()
	target_rune._empower()
	_create_floating_text(tile, "Empowered %s" % target_rune.name)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_same_segment_tile_cards(hover_tile, TileCardType.PRODUCER)
