extends Rune

var score_multiplier: int = 1

# +30 score. Consumes the next adjacent rune in the trigger order to permanently double it's score.
func _on_activate_rune(tile: Hex) -> void:
	# Only consume the rune directly after this one in trigger order, and only when in sequence.
	if can_consume_immediate_following_rune(tile):
		var next_rune := get_immediate_following_rune(tile)
		if next_rune != null:
			score_multiplier += 1
			destroy_placed_rune(tile, next_rune)
			AudioManager.play_ui_sound(UISounds.RUNE_BREAK)
	

	score_value *= score_multiplier
	GameManager.turn_score += score_value
	add_score(tile, score_value)
