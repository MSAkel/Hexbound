extends TileCard
## +15 Flavour. When another card in this course spoils, permanently gain +10 Flavour.

const BREAK_GROWTH := 10


func _on_activate_tile_card(tile: Hex) -> void:
	add_flavour(tile, _get_production_amount())


func on_other_segment_card_broke(_broken: TileCard, tile: Hex) -> void:
	_grow_permanent(tile, self, float(BREAK_GROWTH), "+%d" % BREAK_GROWTH)
