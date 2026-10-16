extends MealCard

## A random 10 to 20 Mult each time it is served.

const MIN_MULT := 10
const MAX_MULT := 20


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	if preview:
		return {}
	return {"additive_mult": float(_effect_rng(tile, "vinaigrette").randi_range(MIN_MULT, MAX_MULT))}


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile != null and tile.map != null and not is_recipe_ready(tile):
		return super.get_board_chip(tile)
	return _make_board_chip(
		BoardChipMode.CHANCE,
		"%d-%d" % [MIN_MULT, MAX_MULT],
		ICON_MULT,
		get_chip_panel_color(),
		"Random %d to %d Mult" % [MIN_MULT, MAX_MULT]
	)
