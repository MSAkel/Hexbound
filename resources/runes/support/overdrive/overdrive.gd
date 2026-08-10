extends Rune

# Triggers the effect of the next rune twice. works on support runes
func _init() -> void:
	single_activation_per_turn = true

func _on_activate_rune(tile: Hex) -> void:
	var next_rune: Rune = _get_next_rune_in_trigger_order(tile)
	if next_rune != null:
		var retriggers: Array[Rune] = [next_rune, next_rune]
		queue_rune_triggers(tile, retriggers)
	else:
		_create_floating_text(tile, "Failed")


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var next_rune := _get_next_rune_in_trigger_order(hover_tile)
	if next_rune == null:
		return []
	return _coords_for_placed_runes(hover_tile, [next_rune])
