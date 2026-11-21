class_name TriggerLinkOverlay
extends Node2D

## Chained-trigger bolts during turn resolution.

const TriggerLinkBurstScript := preload("res://scenes/animations/trigger_link_burst.gd")

var _map: HexTileMap


func setup(map: HexTileMap) -> void:
	_map = map


func play_bolt(from_hex: Hex, to_hex: Hex) -> void:
	if _map == null or from_hex == null or to_hex == null or from_hex == to_hex:
		return

	play_bolt_between(_hex_center_local(from_hex), _hex_center_local(to_hex))


## Bolt between two map-local points. Staff slots sit off the grid and use this directly.
func play_bolt_between(from_pos: Vector2, to_pos: Vector2) -> void:
	if _map == null or from_pos.is_equal_approx(to_pos):
		return
	TriggerLinkBurstScript.spawn(self, from_pos, to_pos)


func _hex_center_local(hex: Hex) -> Vector2:
	return _map.base_layer.map_to_local(hex.coordinates)
