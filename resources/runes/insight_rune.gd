# Triggers the tile which it is placed if it has a library. 
# Causes the library on this tile to generate an additional Insight.
extends Rune

func _on_activate_rune(tile: Hex) -> void:
	if tile.active_building != null and tile.active_building.type == Building.BuildingType.LIBRARY:
		tile.active_building.temporary_boost += boosted_generation_amount
		tile.trigger_building_generation()
