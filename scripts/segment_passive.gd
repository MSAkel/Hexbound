class_name SegmentPassive
extends RefCounted

# Character-specific bonuses applied to tiles that belong to a segment of the map.
# Segment shape follows each character's trigger order:
#   Surveyor  → horizontal rows (top-left to bottom-right)
#   Encircler → concentric rings (outer ring to inner)
#   Spiralist → center tile only

const SURVEYOR_SCORE_MULTIPLIER := 2.0
const ENCIRCLER_PROD_TRIGGER_CHANCE := 0.15
const SPIRALIST_CENTER_ACTIVATION_COUNT := 3


# Extra score multiplier from the active character's segment passive.
static func get_score_multiplier(tile: Hex) -> float:
	if tile.active_rune == null:
		return 1.0

	match GameManager.selected_character:
		PlayerCharacter.Type.SURVEYOR:
			return _get_surveyor_score_multiplier(tile)
		_:
			return 1.0


# How many times a tile's rune should fully resolve this activation step.
static func get_activation_count(tile: Hex) -> int:
	if tile.active_rune == null:
		return 1

	match GameManager.selected_character:
		PlayerCharacter.Type.SPIRALIST:
			if tile.map.is_center_tile(tile.coordinates):
				return SPIRALIST_CENTER_ACTIVATION_COUNT
		_:
			pass

	return 1


# Segment passives that fire after a rune's primary effect resolves.
static func apply_post_activation_effects(tile: Hex) -> void:
	if tile.active_rune == null:
		return

	match GameManager.selected_character:
		PlayerCharacter.Type.ENCIRCLER:
			_apply_encircler_post_activation(tile)


# Surveyor: producer runes on the first tile of each row earn double score.
static func _get_surveyor_score_multiplier(tile: Hex) -> float:
	if tile.active_rune.type != Rune.RuneType.PRODUCER:
		return 1.0
	if not tile.map.is_first_tile_of_row_segment(tile.coordinates):
		return 1.0

	return SURVEYOR_SCORE_MULTIPLIER


# Encircler: a support rune on the first tile of a ring may re-trigger producers on that ring.
static func _apply_encircler_post_activation(tile: Hex) -> void:
	if tile.active_rune.type != Rune.RuneType.SUPPORT:
		return
	if not tile.map.is_first_tile_of_ring_segment(tile.coordinates):
		return

	var ring: int = tile.map.get_tile_ring_distance(tile.coordinates)
	var triggered_producers: Array[Rune] = []

	# Each producer on the same ring gets an independent 10% chance to activate again.
	for coords: Vector2i in tile.map.get_tiles_in_ring(ring):
		var hex: Hex = tile.map.map_data[coords]
		if hex.active_rune == null:
			continue
		if hex.active_rune.type != Rune.RuneType.PRODUCER:
			continue
		if randf() >= ENCIRCLER_PROD_TRIGGER_CHANCE:
			continue
		triggered_producers.append(hex.active_rune)

	if triggered_producers.is_empty():
		return

	tile.active_rune.queue_rune_triggers(tile, triggered_producers)
