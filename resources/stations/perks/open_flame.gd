extends StationPerk

## Open Flame: matching Ingredients here have a chance to be Garnished as they trigger.
@export var chance: float = 0.25


func before_card_triggers(_seg: int, tile: Hex, card: TileCard) -> void:
	if card.type != TileCard.TileCardType.INGREDIENT or not matches(card):
		return
	if card.garnish_stacks > 0 or EventManager.are_garnishes_blocked():
		return
	if card._effect_rng(tile, "open_flame").randf() < chance:
		card.add_garnish()
