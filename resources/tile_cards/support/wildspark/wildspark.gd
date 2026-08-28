extends TileCard

const BONUS_TRIGGER_COUNT := 3

# Triggers a random adjacent rune, if all adjacent tiles contain a different rune, triggers 3 instead.
func _on_activate_tile_card(tile: Hex) -> void:
	var adjacent_runes := _get_all_adjacent_tile_cards(tile)
	if adjacent_runes.is_empty():
		failed_tile_card_text(tile)
		return

	var trigger_count := 1
	if _all_adjacent_tiles_have_unique_runes(tile, adjacent_runes):
		trigger_count = BONUS_TRIGGER_COUNT

	var to_trigger: Array[TileCard] = []
	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	for _i in range(trigger_count):
		to_trigger.append(RunRng.pick_random_placed_tile_card(adjacent_runes, rng, tile.map))

	if not _try_queue_tile_card_triggers(tile, to_trigger):
		return

	_create_floating_text(tile, "Triggered %s runes" % trigger_count)


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_placed_tile_cards(hover_tile, _get_all_adjacent_tile_cards(hover_tile))


# Bonus when every map neighbor is occupied and each adjacent rune has a unique id.
func _all_adjacent_tiles_have_unique_runes(tile: Hex, adjacent_runes: Array[TileCard]) -> bool:
	var adjacent_hexes := tile.map.get_all_adjacent_hexes(tile.coordinates)
	if adjacent_runes.size() != adjacent_hexes.size():
		return false

	var seen_ids: Dictionary = {}
	for rune: TileCard in adjacent_runes:
		if seen_ids.has(rune.id):
			return false
		seen_ids[rune.id] = true
	return true
