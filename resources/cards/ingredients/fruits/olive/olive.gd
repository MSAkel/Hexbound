extends TileCard
## +10 Flavour for each time this card already triggered this Hour.

const PER_EARLIER_TRIGGER := 10.0


func _effect_amount(_tile: Hex) -> float:
	# register_tile_card_activation already counted the current fire.
	var earlier := maxi(GameManager.get_tile_card_activation_count_this_turn(self) - 1, 0)
	if not GameManager.is_processing_turn:
		earlier = 0
	return _get_production_amount() + PER_EARLIER_TRIGGER * float(earlier)
