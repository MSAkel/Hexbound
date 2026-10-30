extends MealCard

## +80 Flavour. Doubled while a Wine is being served on any station, this one included.
## The Wine counts when its Grape is on its station and it is not idle in a locked Meal slot.
## It does not need to have fired yet, so the chip and the payout agree whatever the order.
## Several Wines still double it only once.

const WINE_ID := "wine"
const WINE_SCALE := 2.0


func _meal_outputs(tile: Hex, _preview: bool) -> Dictionary:
	var flavour := _get_production_amount()
	if not _serving_wines(tile).is_empty():
		flavour *= WINE_SCALE
	return {"flavour": int(round(flavour))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _serving_wines(hover_tile)))
	return coords


## Every placed Wine that would be served right now.
func _serving_wines(tile: Hex) -> Array[TileCard]:
	var wines: Array[TileCard] = []
	if tile == null or tile.map == null:
		return wines
	for card: TileCard in _get_all_placed_tile_cards(tile, TileCardType.MEAL):
		if card.id != WINE_ID:
			continue
		var wine := card as MealCard
		if wine != null and wine.is_serving(_hex_for(tile, card)):
			wines.append(card)
	return wines
