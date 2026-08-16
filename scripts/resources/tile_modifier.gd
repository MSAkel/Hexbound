class_name TileModifier
extends RefCounted

# Player-applied tile modifier for future mechanics.
# Unlike SegmentPassiveModifier, these can be placed during a run on eligible tiles.

var name: String
var description: String
var icon: Texture2D


# Segment-passive tiles are reserved at run start and never accept applied modifiers.
static func can_apply_to(hex: Hex) -> bool:
	return not hex.is_reserved_for_segment_passive()


static func can_replace_on(hex: Hex) -> bool:
	if hex.is_reserved_for_segment_passive():
		return false
	return hex.tile_modifier == null
