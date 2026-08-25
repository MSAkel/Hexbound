extends TileCard
## Breaks target card then gain 3 gold

const GOLD_REWARD := 3


func apply_on_placement(tile: Hex) -> void:
	var target := tile.active_tile_card
	if target == null:
		return

	_destroy_placed_tile_card(tile, target)
	AudioManager.play_sfx(UISounds.RUNE_BREAK)
	add_gold(tile, GOLD_REWARD)
