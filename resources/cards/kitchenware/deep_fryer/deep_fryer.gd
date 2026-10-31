extends TileCard

## +2 Mult. The Following Ingredient gains x2 output on its next fire, x3 when it is Potato or Chicken.

const TARGET_COUNT := 1
const SCALE := 2.0
const FAVOURITE_SCALE := 3.0
const FAVOURITE_IDS: Array[String] = ["potato", "chicken"]


func _on_activate_tile_card(tile: Hex) -> void:
	_pay_kitchenware_mult(tile)
	var targets := _effect_preview_cards(tile)
	if targets.is_empty():
		failed_tile_card_text(tile)
		return
	for target: TileCard in targets:
		var factor := FAVOURITE_SCALE if target.id in FAVOURITE_IDS else SCALE
		if _try_scale_tile_card(tile, target, factor):
			_create_fired_floating_text(tile, target)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	return _get_next_tile_cards_in_trigger_order(tile, TARGET_COUNT, TileCard.PRODUCER_TYPE_FILTER)
