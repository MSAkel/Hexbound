extends TileCard

 # +2 Energy for every Gold you have
func _on_activate_tile_card(tile: Hex) -> void:
	var gold_count := GoldManager.amount
	var score_to_add := (gold_count * base_production_amount) + bonus_production_amount
	add_score(tile, score_to_add)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	var gold_count := GoldManager.amount
	return _amount_board_chip((gold_count * base_production_amount) + bonus_production_amount)
