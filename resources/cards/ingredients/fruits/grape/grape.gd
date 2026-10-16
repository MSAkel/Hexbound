extends TileCard

## Beverages on this station get x1.25 output.

const BEVERAGE_SCALE := 1.25


func station_output_scale_for(card: TileCard) -> float:
	return BEVERAGE_SCALE if card.has_ingredient_tag(TAG_BEVERAGE) else 1.0


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_cards_by_kind(hover_tile, TAG_BEVERAGE, QueryScope.SAME_SEGMENT)
