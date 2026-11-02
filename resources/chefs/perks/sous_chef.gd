extends ChefPerk

## Sous Chef: every repeat_every-th Kitchenware trigger each Hour repeats.
## The repeat itself does not count toward the next one.
@export var repeat_every: int = 3


func after_card_triggered(state: Dictionary, tile: Hex, card: TileCard) -> void:
	if tile == null or card == null or card.type != TileCard.TileCardType.KITCHENWARE:
		return
	if not card.can_be_triggered_by_other_card(tile):
		return
	if state.get("hour_repeat_active", false):
		state["hour_repeat_active"] = false
		return
	var count := int(state.get("hour_kitchenware_triggers", 0)) + 1
	state["hour_kitchenware_triggers"] = count
	if repeat_every <= 0 or count % repeat_every != 0:
		return
	state["hour_repeat_active"] = true
	card.queue_tile_card_triggers(tile, [card])
