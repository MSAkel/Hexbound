class_name TriggerLinkOverlay
extends Node2D

## Chained-trigger bolts and garnish lightning strikes during turn resolution.

const TriggerLinkBurstScript := preload("res://scenes/animations/trigger_link_burst.gd")
const GarnishStrikeBurstScene := preload("res://scenes/animations/garnish_strike_burst.tscn")

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


## Lightning strike that falls onto the rune receiving garnish. Returns travel time before impact.
func play_garnish_strike(to_hex: Hex) -> float:
	if _map == null or to_hex == null:
		return 0.0

	var burst: GarnishStrikeBurst = GarnishStrikeBurstScene.instantiate()
	add_child(burst)
	var travel := burst.travel_duration
	burst.play(_hex_center_local(to_hex))
	return travel


func _hex_center_local(hex: Hex) -> Vector2:
	return _map.base_layer.map_to_local(hex.coordinates)
