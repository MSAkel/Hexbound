extends StationPerk

## Tempura: matching Ingredients on this station count as Potato for the Deep Fryer.


func counts_as_potato(_seg: int, card: TileCard) -> bool:
	return card.type == TileCard.TileCardType.INGREDIENT and matches(card)
