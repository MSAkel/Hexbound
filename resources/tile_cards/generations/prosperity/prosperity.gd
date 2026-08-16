extends TileCard

# +5 score for every 1 gold earned this turn
func _on_activate_tile_card(tile: Hex) -> void:
	var gold_earned := GoldManager.earned_this_turn
	var score_to_add := gold_earned * _get_production_amount()
	add_score(tile, score_to_add)
