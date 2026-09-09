extends TileCard

## Applies x2 course Mult when the previous occupied card in fire order is a Seasoning.

const XMULT_FACTOR := 2.0


func _on_activate_tile_card(tile: Hex) -> void:
	if _preceding_seasoning(tile) == null:
		failed_tile_card_text(tile)
		return
	multiply_multiplicative_mult(tile, XMULT_FACTOR)


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and _preceding_seasoning(tile) == null:
		return _stat_board_chip()
	return _multiplicative_mult_board_chip(XMULT_FACTOR)


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var seasoning := _preceding_seasoning(tile)
	if seasoning == null:
		return []
	return [seasoning]


func _preceding_seasoning(tile: Hex) -> TileCard:
	if tile == null or tile.map == null:
		return null
	var previous := _get_previous_tile_cards_in_trigger_order(tile, 1)
	if previous.is_empty():
		return null
	var card := previous[0]
	if not card.has_ingredient_tag(TAG_SEASONING):
		return null
	return card
