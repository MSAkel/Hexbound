extends Rune
# Triggers every adjacent tile with a minting facility. Does not trigger the tile it is placed on
func _on_activate_rune(tile: Hex) -> void:
	var surrounding_tiles = tile.map.base_layer.get_surrounding_cells(tile.coordinates)
	for coords in surrounding_tiles:
		if tile.map.map_data.has(coords):
			var surrounding_hex = tile.map.map_data[coords]
			if surrounding_hex.active_building != null and surrounding_hex.active_building.type == Building.BuildingType.MINTING_FACILITY:
				surrounding_hex.trigger_building_generation()
