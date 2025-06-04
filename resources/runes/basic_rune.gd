extends Rune


func activate_rune(tile: Hex) -> void:
	if tile.active_building != null:
		tile.trigger_building_generation()
