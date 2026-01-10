extends Rune

func _on_activate_rune(tile: Hex) -> void:
	if tile.active_building != null and tile.active_building.type == Building.BuildingType.MINTING_FACILITY:
		tile.active_building.temporary_boost += boosted_generation_amount
		tile.trigger_building_generation()
