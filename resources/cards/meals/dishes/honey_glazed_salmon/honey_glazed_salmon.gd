extends MealCard

## Needs Salmon and Honey. +60 Flavour, +2 Mult for each time a Honey on its station has triggered
## this Hour (retriggers count). Honey passed down by a Cutting Board counts too. Before the Hour,
## the chip assumes each Honey triggers once. No xMult (Meals no longer give it). Untuned.

const HONEY_ID := "honey"
const MULT_PER_HONEY_TRIGGER := 2.0


func _meal_outputs(tile: Hex, preview: bool) -> Dictionary:
	return {
		"flavour": int(round(_get_production_amount())),
		"additive_mult": MULT_PER_HONEY_TRIGGER * float(_honey_triggers(tile, preview)),
	}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _honeys(hover_tile)))
	return coords


func _honey_triggers(tile: Hex, preview: bool) -> int:
	var triggers := 0
	for honey: TileCard in _honeys(tile):
		var count := GameManager.get_tile_card_activation_count_this_turn(honey)
		triggers += maxi(count, 1) if preview else count
	return triggers


func _honeys(tile: Hex) -> Array[TileCard]:
	var honeys: Array[TileCard] = []
	if tile == null:
		return honeys
	for card: TileCard in _station_cards(tile):
		if card.id == HONEY_ID:
			honeys.append(card)
	return honeys
