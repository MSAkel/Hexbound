extends TileCard
## +15 Flavour. When another card in this course spoils, permanently gain +10 Flavour.

const BREAK_GROWTH := 10


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())


func on_other_segment_card_broke(_broken: TileCard, tile: Hex) -> void:
	bonus_production_amount += float(BREAK_GROWTH)
	_create_floating_text(tile, "+%d" % BREAK_GROWTH, Color.AQUA, ICON_ENERGY)
	tile.refresh_tile_card_visual_state()
