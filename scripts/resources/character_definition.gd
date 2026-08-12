class_name CharacterDefinition
extends Resource

# Data for one playable character: map layout rules, segment grouping, and passives.

enum TriggerOrderStrategy {
	ZIGZAG_ROWS,
	RINGS_OUTWARD,
	RINGS_INWARD,
	NUMBERED_GRID,
}

enum SegmentKeyStrategy {
	ROW_Y,
	RING,
	NUMBERED_GRID,
}

@export var id: String = ""
@export var display_name: String = ""

@export var trigger_order_strategy: TriggerOrderStrategy = TriggerOrderStrategy.ZIGZAG_ROWS
@export var trigger_order_display_name: String = ""
@export_multiline var trigger_order_description: String = ""
@export var trigger_order_preview: Texture2D

# Used when trigger_order_strategy is NUMBERED_GRID.
@export var numbered_order_grid: Array = []
@export var segment_starts: Array[int] = []

@export var segment_key_strategy: SegmentKeyStrategy = SegmentKeyStrategy.ROW_Y

@export var passive_places_on_center_tile: bool = false
@export var passive_modifier_type: SegmentPassiveModifier.Type = SegmentPassiveModifier.Type.FIRST_ROW
@export var passive_name: String = ""
@export_multiline var passive_description: String = ""
@export var passive_icon: Texture2D
@export var passive_icon_preview: Texture2D

@export var uses_standard_starting_hand: bool = true
@export_multiline var character_passive_description: String = "Passive ability: TBD"
