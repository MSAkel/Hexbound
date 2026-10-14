extends StaffCard

## Each Kitchenware on this station sends one fire to a Kitchenware on another station per Hour.
## Finished stations stay closed, so only stations still waiting to fire can be reached.


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if ctx.is_staff_caused_activation() or not ctx.is_on_station(tile):
		return
	if card.type != TileCard.TileCardType.KITCHENWARE:
		return
	# Once per source card. Two cards that fire each other could otherwise loop through here.
	var served: Array = ctx.hour_state.get_or_add("served", [])
	if card in served:
		return
	var candidates := _open_kitchenware_elsewhere(ctx)
	if candidates.is_empty():
		return
	served.append(card)
	var picked := RunRng.pick_random_placed_tile_card(candidates, ctx.rng("runner"), ctx.map)
	var targets: Array[TileCard] = [picked]
	ctx.queue_triggers(targets)


func _open_kitchenware_elsewhere(ctx: StaffContext) -> Array[TileCard]:
	var result: Array[TileCard] = []
	for card: TileCard in ctx.map.get_all_placed_tile_cards(TileCard.TileCardType.KITCHENWARE):
		var hex := ctx.map.get_hex_for_tile_card(card)
		if hex == null:
			continue
		var segment_index := ctx.map.get_segment_index(hex.coordinates)
		if segment_index == ctx.slot or ctx.map.is_segment_resolved(segment_index):
			continue
		result.append(card)
	return result
