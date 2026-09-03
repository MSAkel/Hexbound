extends TileCard

## +30 Flavour. Consume the Following card to permanently double this card's Flavour.

var score_bonus: int = 1

func _on_activate_tile_card(tile: Hex) -> void:
	## Only consume the card directly after this one in fire order
	if _can_consume_next_tile_card_in_trigger_order(tile):
		var next_rune := _get_next_tile_card_in_trigger_order(tile)
		if next_rune != null:
			score_bonus += 1
			_destroy_placed_tile_card(tile, next_rune)
			AudioManager.play_sfx(UISounds.SPOIL_BREAK)
	
	var prod_amount = _get_production_amount()
	prod_amount *= score_bonus
	add_score(tile, prod_amount)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip(_get_production_amount() * score_bonus)


func capture_placed_save_state() -> Dictionary:
	return {"score_bonus": score_bonus}


func apply_placed_save_state(data: Dictionary) -> void:
	score_bonus = maxi(int(data.get("score_bonus", 1)), 1)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_rune := _get_next_tile_card_in_trigger_order(hover_tile)
	if next_rune == null:
		return []
	return _coords_for_placed_tile_cards(hover_tile, [next_rune])
