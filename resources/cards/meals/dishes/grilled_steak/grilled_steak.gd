extends MealCard

## Needs Steak. +60 Flavour. On its first trigger each Hour it Garnishes itself once for each of:
## Salt on its station, Black Pepper on its station, a Wine being served on any station. At most 2
## of these Garnishes per Hour (the Garnish stack cap still applies). The Garnish lasts the Hour,
## like any other, so retriggers that Hour are boosted too.
## A Wine counts when its Grape is on its station and it is not idle in a locked Meal slot; it does
## not need to have fired yet.

const WINE_ID := "wine"
const SEASONING_IDS: Array[String] = ["salt", "black_pepper"]
const MAX_SELF_GARNISHES := 2


func _before_trigger(tile: Hex) -> void:
	if GameManager.get_tile_card_activation_count_this_turn(self) != 1:
		return
	if not is_recipe_ready(tile):
		return
	for _i in mini(_garnish_sources(tile), MAX_SELF_GARNISHES):
		if not add_garnish():
			break


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"flavour": int(round(_get_production_amount()))}


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _station_seasonings(hover_tile)))
	coords.append_array(_coords_for_placed_tile_cards(hover_tile, _serving_wines(hover_tile)))
	return coords


func _garnish_sources(tile: Hex) -> int:
	var sources := 0
	var seasonings := _station_seasonings(tile)
	for card_id: String in SEASONING_IDS:
		if seasonings.any(func(card: TileCard) -> bool: return card.id == card_id):
			sources += 1
	if not _serving_wines(tile).is_empty():
		sources += 1
	return sources


## Salt and Black Pepper on its station (including any passed down by a Cutting Board).
func _station_seasonings(tile: Hex) -> Array[TileCard]:
	var found: Array[TileCard] = []
	if tile == null:
		return found
	for card: TileCard in _station_cards(tile):
		if card.id in SEASONING_IDS:
			found.append(card)
	return found


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
