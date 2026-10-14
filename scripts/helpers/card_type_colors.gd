class_name CardTypeColors
extends RefCounted

## Accent color per card type. Shared by the card face and the board token so both read as one card.

const INGREDIENT := Color(0.1764706, 0.49019608, 0.50980395, 1.0)
const KITCHENWARE := Color(0.34117648, 0.5372549, 0.30588236, 1.0)
const MEAL := Color(0.6862745, 0.29803923, 0.28235295, 1.0)


static func for_card(card: Card) -> Color:
	if card is TileCard:
		match (card as TileCard).type:
			TileCard.TileCardType.INGREDIENT:
				return INGREDIENT
			TileCard.TileCardType.MEAL:
				return MEAL
			TileCard.TileCardType.KITCHENWARE:
				return KITCHENWARE
	# Staff cards borrow the Kitchenware accent until they get their own.
	if card is StaffCard:
		return KITCHENWARE
	return INGREDIENT
