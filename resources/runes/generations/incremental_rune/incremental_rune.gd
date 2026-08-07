extends Rune

# +5 points increasing by 5 every 2 turns up to a maximum of 70
func _on_activate_rune(tile: Hex) -> void:
	var points_to_add := base_production_amount
	add_score(tile, points_to_add)
	base_production_amount += 5
	if base_production_amount > 70:
		base_production_amount = 70