extends TileCard

## Pays bonus_per_card extra Flavour for each card of bonus_kind in bonus_scope.
## Shared by Corn (adjacent Kitchenware, counted once), Sausage (adjacent Seasoning)
## and Steak (Seasoning on its station). The .tres sets the numbers.

@export var bonus_kind: StringName = &""
@export var bonus_scope: QueryScope = QueryScope.ADJACENT
@export var bonus_per_card: float = 0.0
## Most cards that count. -1 counts them all.
@export var max_counted: int = -1


func _effect_amount(tile: Hex) -> float:
	if tile == null:
		return _get_production_amount()
	var counted := _effect_preview_cards(tile).size()
	if max_counted >= 0:
		counted = mini(counted, max_counted)
	return _get_production_amount() + bonus_per_card * float(counted)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _cards_by_kind(tile, bonus_kind, bonus_scope)
