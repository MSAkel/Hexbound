extends Rune

func _on_activate_rune(tile: Hex) -> void:
	if tile.active_building != null and tile.active_building.type == Building.BuildingType.LUMBER_CAMP:
		tile.active_building.temporary_boost += boosted_generation_amount
		tile.trigger_building_generation()
