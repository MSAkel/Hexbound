extends TileCard

## Pays its Flavour, Garnished when an adjacent spot holds a card of neighbour_kind.
## Shared by Lettuce, Apple, Meat and Shrimp. The .tres sets the kind.

## Tag to look for next to this card, such as &"seasoning" or &"kitchenware".
## Empty means any other Ingredient.
@export var neighbour_kind: StringName = &""


func _on_activate_tile_card(tile: Hex) -> void:
	if not _effect_preview_cards(tile).is_empty():
		_garnish_self_now()
	_pay_effect_amount(tile)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	if neighbour_kind == &"":
		return _get_all_adjacent_tile_cards(tile, TileCardType.INGREDIENT)
	return _cards_by_kind(tile, neighbour_kind, QueryScope.ADJACENT)
