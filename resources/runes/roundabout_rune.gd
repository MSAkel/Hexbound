extends Rune

func activate_rune(tile: Hex) -> void:
	var surrounding_tiles = tile.map.base_layer.get_surrounding_cells(tile.coordinates)
	for coords in surrounding_tiles:
		if tile.map.map_data.has(coords):
			var surrounding_hex = tile.map.map_data[coords]
			if surrounding_hex.active_building != null:
				surrounding_hex.trigger_building_generation()
