class_name CharacterDefinition
extends Resource

# Data for one playable character: map layout rules and segment grouping.

# Rule that sorts tiles when runes activate on the map.
enum TriggerOrderStrategy {
	# Left-to-right, top-to-bottom zigzag across visual rows.
	ZIGZAG_ROWS,
	# Center tile first, then each hex ring outward.
	RINGS_OUTWARD,
	# Outer rings first, then inward to the center.
	RINGS_INWARD,
	# Custom fire order from numbered_order_grid.
	NUMBERED_GRID,
}

# Rule that groups consecutive tiles in trigger order into segments.
enum SegmentKeyStrategy {
	# Same screen Y (a visual row) is one segment.
	ROW_Y,
	# Same distance from the map center is one segment.
	RING,
	# Segment index comes from segment_starts along the numbered order.
	NUMBERED_GRID,
}

# Stable lookup/save key (e.g. "surveyor"), not shown to the player.
@export var id: String = ""
# Player-facing character name (e.g. "The Surveyor").
@export var display_name: String = ""
# Portrait used on the character selection UI.
@export var icon: Texture2D = null

# Which TriggerOrderStrategy this character uses.
@export var trigger_order_strategy: TriggerOrderStrategy = TriggerOrderStrategy.ZIGZAG_ROWS
# Short UI label for the activation path (e.g. "Top-left → bottom-right").
@export var trigger_order_display_name: String = ""
# Longer UI explanation of how runes fire for this character.
@export_multiline var trigger_order_description: String = ""
# Diagram of the activation path shown in character details.
@export var trigger_order_preview: Texture2D

# Custom tile sequence used when trigger_order_strategy is NUMBERED_GRID.
@export var numbered_order_grid: Array = []
# Order indices where a new segment begins (also drives the Segments count in UI).
@export var segment_starts: Array[int] = []

# Which SegmentKeyStrategy this character uses to split the map.
@export var segment_key_strategy: SegmentKeyStrategy = SegmentKeyStrategy.ROW_Y

# Number of segments in the map for this character.
@export var segments_count: int = 0
# Tile counts per segment in trigger order. Used by loot filters without a live map.
@export var segment_sizes: Array[int] = []


## True when this layout has at least one segment with exactly `size` tiles.
func has_segment_of_size(size: int) -> bool:
	for segment_size: int in segment_sizes:
		if segment_size == size:
			return true
	return false


## Largest segment on this layout, or 0 when sizes are unset.
func get_max_segment_size() -> int:
	var largest := 0
	for segment_size: int in segment_sizes:
		largest = maxi(largest, segment_size)
	return largest
