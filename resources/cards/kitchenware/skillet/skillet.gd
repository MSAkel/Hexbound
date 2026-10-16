extends TileCard

## +1 Mult. The Following 2 Ingredients gain x1.5 output on their next fire, x2 when they are Meat.

const TARGET_COUNT := 2
const SCALE := 1.5
const MEAT_SCALE := 2.0


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		return
	for target: TileCard in targets:
		var factor := MEAT_SCALE if target.has_ingredient_tag(TAG_PROTEIN) else SCALE
		if _try_scale_tile_card(tile, target, factor):
			_create_fired_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
