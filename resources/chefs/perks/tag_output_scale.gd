extends ChefPerk

## Cards carrying any of target_tags get x scale output (Sommelier: Beverages x1.5).
## Ingredients only when ingredients_only is set.
@export var target_tags: Array[StringName] = []
@export var scale: float = 2.0
@export var ingredients_only: bool = false


func output_scale_for(_state: Dictionary, _tile: Hex, card: TileCard) -> float:
	if card == null:
		return 1.0
	if ingredients_only and card.type != TileCard.TileCardType.INGREDIENT:
		return 1.0
	for tag: StringName in target_tags:
		if card.has_ingredient_tag(tag):
			return scale
	return 1.0
