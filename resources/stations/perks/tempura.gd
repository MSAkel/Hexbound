extends StationPerk

## Tempura: the Deep Fryer triggers matching Ingredients on this station once more.


func gets_extra_fryer_trigger(_seg: int, card: TileCard) -> bool:
	return card.type == TileCard.TileCardType.INGREDIENT and matches(card)
