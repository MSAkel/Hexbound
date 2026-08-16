extends TileCard

 # +2 score for every gold you have
func _on_activate_tile_card(tile: Hex) -> void:
	var gold_count := GoldManager.amount
	var score_to_add := (gold_count * base_production_amount) + bonus_production_amount
	add_score(tile, score_to_add)
