extends TileCard

## Pays partner_bonus extra Flavour when a partner_id card sits next to it.
## Shared by Salt and Black Pepper. The .tres names the partner.

@export var partner_id: String = ""
@export var partner_bonus: float = 10.0


func _effect_amount(tile: Hex) -> float:
	if tile == null or _effect_preview_cards(tile).is_empty():
		return _get_production_amount()
	return _get_production_amount() + partner_bonus


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var partners: Array[TileCard] = []
	for card: TileCard in _get_all_adjacent_tile_cards(tile):
		if card.id == partner_id:
			partners.append(card)
	return partners
