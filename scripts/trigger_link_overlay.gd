class_name TriggerLinkOverlay
extends Node2D

## Spark burst from chained trigger source to target during turn resolution.

const TriggerLinkBurstScript := preload("res://scenes/animations/trigger_link_burst.gd")

var _map: HexTileMap


func setup(map: HexTileMap) -> void:
	_map = map


func play_bolt(from_hex: Hex, to_hex: Hex) -> void:
	if _map == null or from_hex == null or to_hex == null or from_hex == to_hex:
		return

	var from_pos := _hex_center_local(from_hex)
	var to_pos := _hex_center_local(to_hex)
	TriggerLinkBurstScript.spawn(self, from_pos, to_pos)


func _hex_center_local(hex: Hex) -> Vector2:
	return _map.base_layer.map_to_local(hex.coordinates)
