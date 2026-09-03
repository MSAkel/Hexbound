extends TileCard

## +5 Flavour. Every 2nd fire: permanently gain +5 Flavour.
func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())

	## Permanent +5 applies after scoring, so this fire still uses the current amount.
	activation_count += 1
	if activation_count % 2 == 0:
		bonus_production_amount += 5


func capture_placed_save_state() -> Dictionary:
	return {"activation_count": activation_count}


func apply_placed_save_state(data: Dictionary) -> void:
	activation_count = int(data.get("activation_count", 0))
