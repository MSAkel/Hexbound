extends TileCard

## +30 Score. Consume the next card to permanently double this card's Score.

var score_bonus: int = 1

func _on_activate_tile_card(tile: Hex) -> void:
	## Only consume the card directly after this one in trigger order
	if _can_consume_next_tile_card_in_trigger_order(tile):
		var next_rune := _get_next_tile_card_in_trigger_order(tile)
		if next_rune != null:
			score_bonus += 1
			_destroy_placed_tile_card(tile, next_rune)
			AudioManager.play_sfx(UISounds.RUNE_BREAK)
	
	var prod_amount = _get_production_amount()
	prod_amount *= score_bonus
	add_score(tile, prod_amount)
