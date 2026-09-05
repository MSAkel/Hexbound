extends TileCard

const MIN_MULT := 1
const MAX_MULT := 20


## Generates a random amount of Mult from 1 through 20.
func _on_activate_tile_card(tile: Hex) -> void:
	var mult_amount := _effect_rng(tile).randi_range(MIN_MULT, MAX_MULT)
	add_additive_mult(tile, mult_amount)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _make_board_chip(
		BoardChipMode.CHANCE,
		"%d-%d" % [MIN_MULT, MAX_MULT],
		ICON_MULT,
		get_chip_panel_color(),
		"Random Mult"
	)

## +1-20 Mult
