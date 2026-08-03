extends Rune

# Triggers the effect of the next rune twice. works on support runes
# Ignores any retrigger effects after the first activation each turn.
func activate_rune(tile: Hex, score_multiplier: float = 1.0) -> void:
	if GameManager.has_rune_activated_this_turn(self):
		return
	super.activate_rune(tile, score_multiplier)


func _on_activate_rune(tile: Hex) -> void:
	var next_rune: Rune = get_immediate_following_rune(tile)
	if next_rune != null:
		next_rune.activate_rune(tile)
		next_rune.activate_rune(tile)
