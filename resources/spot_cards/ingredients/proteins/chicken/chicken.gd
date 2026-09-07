extends TileCard
## +24 Flavour if this is the first Ingredient in the course, otherwise +8.

const FIRST_PRODUCER_AMOUNT := 24
const OTHER_PRODUCER_AMOUNT := 8


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_effect_amount(tile)


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return float(FIRST_PRODUCER_AMOUNT)
	if _is_first_producer_in_segment(tile):
		return float(FIRST_PRODUCER_AMOUNT)
	return float(OTHER_PRODUCER_AMOUNT)
