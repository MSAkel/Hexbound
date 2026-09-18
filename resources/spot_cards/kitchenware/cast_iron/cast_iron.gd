extends TileCard

# Triggers the effect of the next rune twice. works on support runes
func _init() -> void:
	single_activation_per_turn = true

func _on_activate_tile_card(tile: Hex) -> void:
	var next_cards := _effect_preview_cards(tile)
	if next_cards.is_empty():
		failed_tile_card_text(tile)
		return

	var next_rune := next_cards[0]
	_try_queue_tile_card_triggers(tile, [next_rune, next_rune])


func _effect_preview_cards(tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	var next_rune := _get_next_tile_card_in_trigger_order(tile)
	if next_rune != null:
		cards.append(next_rune)
	return cards
