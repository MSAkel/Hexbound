class_name StationLevelFlash
extends Control

## Golden flash around a Station badge on level up: a glow over the badge that fades, and two rings
## that spread outwards one after the other. Frees itself when done.

const GLOW_IN := 0.1
const GLOW_OUT := 0.6
const RING_TIME := 0.65
const RING_DELAY := 0.16
## How far each ring travels beyond the badge, in pixels.
const RING_SPREAD := 10.0
const OUTER_RING_SPREAD := 15.0

@onready var _glow: Panel = %Glow
@onready var _ring: Panel = %Ring
@onready var _outer_ring: Panel = %OuterRing


## Call once the node is in the tree. speed is the game speed.
func play(speed: float) -> void:
	_glow.modulate.a = 0.0
	_ring.modulate.a = 0.0
	_outer_ring.modulate.a = 0.0

	var tween := create_tween().set_parallel(true)
	tween.tween_property(_glow, "modulate:a", 1.0, GLOW_IN / speed)
	tween.tween_property(_glow, "modulate:a", 0.0, GLOW_OUT / speed).set_delay(GLOW_IN / speed).set_trans(
		Tween.TRANS_SINE
	)
	_spread(tween, _ring, RING_SPREAD, 0.0, speed)
	_spread(tween, _outer_ring, OUTER_RING_SPREAD, RING_DELAY, speed)
	tween.chain().tween_callback(queue_free)


func _spread(tween: Tween, ring: Panel, distance: float, delay: float, speed: float) -> void:
	var start := delay / speed
	var time := RING_TIME / speed
	tween.tween_property(ring, "modulate:a", 0.0, time).from(1.0).set_delay(start).set_trans(
		Tween.TRANS_QUAD
	).set_ease(Tween.EASE_IN)
	for side: String in ["offset_left", "offset_top"]:
		tween.tween_property(ring, side, -distance, time).set_delay(start).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
	for side: String in ["offset_right", "offset_bottom"]:
		tween.tween_property(ring, side, distance, time).set_delay(start).set_trans(Tween.TRANS_CUBIC).set_ease(
			Tween.EASE_OUT
		)
