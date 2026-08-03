extends Rune

const BONUS_TRIGGER_COUNT := 3

# Triggers a random adjacent rune, if all adjacent tiles contain a different rune, triggers 3 instead.
func _on_activate_rune(tile: Hex) -> void:
	var adjacent_runes := get_adjacent_runes(tile)
	if adjacent_runes.is_empty():
		return
	
	var trigger_count := 1
	if _all_adjacent_tiles_have_unique_runes(tile, adjacent_runes):
		trigger_count = BONUS_TRIGGER_COUNT
	
	var to_trigger: Array[Rune] = []
	for _i in range(trigger_count):
		to_trigger.append(adjacent_runes.pick_random())
	
	queue_rune_triggers(tile, to_trigger)


# Bonus when every map neighbor is occupied and each adjacent rune has a unique id.
func _all_adjacent_tiles_have_unique_runes(tile: Hex, adjacent_runes: Array[Rune]) -> bool:
	var adjacent_hexes := tile.map.get_adjacent_hexes(tile.coordinates)
	if adjacent_runes.size() != adjacent_hexes.size():
		return false
	
	var seen_ids: Dictionary = {}
	for rune: Rune in adjacent_runes:
		if seen_ids.has(rune.id):
			return false
		seen_ids[rune.id] = true
	return true
