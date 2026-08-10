extends Rune

var score_bonus: int = 1

# +30 score. Consumes the next adjacent rune in the trigger order to permanently double it's score.
func _on_activate_rune(tile: Hex) -> void:
	# Only consume the rune directly after this one in trigger order, and only when in sequence.
	if _can_consume_next_rune_in_trigger_order(tile):
		var next_rune := _get_next_rune_in_trigger_order(tile)
		if next_rune != null:
			score_bonus += 1
			_destroy_placed_rune(tile, next_rune)
			AudioManager.play_sfx(UISounds.RUNE_BREAK)
	
	var prod_amount = _get_production_amount()
	prod_amount *= score_bonus
	add_score(tile, prod_amount)
