extends DishCard

## +60 Flavour when the prefix is Steak plus Kitchenware. Doubles the first Following neighbour if it is wine.
## Steak is the named card, not any Protein.

const STEAK_CARD_ID := "steak"


func _plated_flavour_from_recipe(_recipe: Array[TileCard]) -> int:
	return int(round(_get_production_amount()))


func _on_activate_tile_card(tile: Hex) -> void:
	super._on_activate_tile_card(tile)
	if not is_recipe_ready(tile):
		return
	_try_double_following_wine(tile)


func card_matches_needed_tag(card: TileCard) -> bool:
	if card == null:
		return false
	if card.type == TileCardType.KITCHENWARE:
		return true
	return _is_steak_card(card)


func _recipe_bag_matches(cards: Array[TileCard]) -> bool:
	var steaks := 0
	var kitchenware := 0
	for card: TileCard in cards:
		if card.type == TileCardType.KITCHENWARE:
			kitchenware += 1
			continue
		if _is_steak_card(card):
			steaks += 1
			continue
		return false
	return steaks == 1 and kitchenware == 1


func _recipe_bag_text() -> String:
	return "1 Steak, 1 Kitchenware"


func _is_steak_card(card: TileCard) -> bool:
	return card != null and card.id == STEAK_CARD_ID


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	var coords := super.get_trigger_preview_coords(hover_tile)
	var neighbour := _get_following_neighbouring_card(hover_tile)
	if neighbour == null or hover_tile.map == null:
		return coords
	var hex := hover_tile.map.get_hex_for_tile_card(neighbour)
	if hex != null:
		coords.append(hex.coordinates)
	return coords


func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	var gold := super.get_trigger_preview_gold_coords(hover_tile)
	var neighbour := _get_following_neighbouring_card(hover_tile)
	if not _is_wine_card(neighbour) or hover_tile.map == null:
		return gold
	var hex := hover_tile.map.get_hex_for_tile_card(neighbour)
	if hex != null:
		gold.append(hex.coordinates)
	return gold


func _try_double_following_wine(tile: Hex) -> void:
	var neighbour := _get_following_neighbouring_card(tile)
	if not _is_wine_card(neighbour):
		return
	if not _try_empower_tile_card(tile, neighbour):
		return
	_create_doubled_floating_text(tile, neighbour)


## First occupied adjacent spot that fires after this dish.
func _get_following_neighbouring_card(tile: Hex) -> TileCard:
	var following := _get_following_adjacent_tile_cards(tile)
	if following.is_empty():
		return null
	return following[0]


func _is_wine_card(card: TileCard) -> bool:
	if card == null:
		return false
	if card.id.to_lower().contains("wine"):
		return true
	return card.name.to_lower().contains("wine")
