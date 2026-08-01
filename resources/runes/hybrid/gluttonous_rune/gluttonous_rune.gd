extends Rune

var consumed_runes_count: int = 0

# +30 score. Consumes the next adjacent rune in the trigger order to permanently double it's score.
func _on_activate_rune(tile: Hex) -> void:
	# Only consume the rune directly after this one in trigger order, and only when in sequence.
	if can_consume_immediate_following_rune(tile):
		var next_rune := get_immediate_following_rune(tile)
		if next_rune != null:
			consumed_runes_count += 1
			destroy_placed_rune(tile, next_rune)
			AudioManager.play_ui_sound(UISounds.RUNE_BREAK)
	
	if consumed_runes_count > 0:
		score_value *= consumed_runes_count
	GameManager.turn_score += score_value
	add_score(tile, score_value)
