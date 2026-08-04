class_name SegmentPassive
extends RefCounted

# Gameplay effects for SegmentPassiveModifier tiles assigned at run start.

const SURVEYOR_ACTIVATION_SCALE := 2.0
const ENCIRCLER_PROD_TRIGGER_CHANCE := 0.15
const SPIRALIST_CENTER_ACTIVATION_COUNT := 3


static func get_activation_scale(tile: Hex) -> float:
	if tile.active_rune == null or tile.segment_passive_modifier == null:
		return 1.0

	if tile.segment_passive_modifier.modifier_type != SegmentPassiveModifier.Type.FIRST_ROW:
		return 1.0
	if tile.active_rune.type != Rune.RuneType.PRODUCER:
		return 1.0

	return SURVEYOR_ACTIVATION_SCALE


static func get_activation_count(tile: Hex) -> int:
	if tile.segment_passive_modifier == null:
		return 1

	if tile.segment_passive_modifier.modifier_type == SegmentPassiveModifier.Type.CENTER_TILE:
		return SPIRALIST_CENTER_ACTIVATION_COUNT

	return 1


static func apply_post_activation_effects(tile: Hex) -> void:
	if tile.active_rune == null or tile.segment_passive_modifier == null:
		return

	if tile.segment_passive_modifier.modifier_type == SegmentPassiveModifier.Type.FIRST_CIRCLE:
		_apply_encircler_post_activation(tile)


static func _apply_encircler_post_activation(tile: Hex) -> void:
	if tile.active_rune.type != Rune.RuneType.SUPPORT:
		return

	var triggered_producers: Array[Rune] = []
	for rune: Rune in tile.map.get_runes_on_same_segment_as(tile, Rune.RuneType.PRODUCER):
		if randf() >= ENCIRCLER_PROD_TRIGGER_CHANCE:
			continue
		triggered_producers.append(rune)

	if triggered_producers.is_empty():
		return

	tile.active_rune.queue_rune_triggers(tile, triggered_producers)
