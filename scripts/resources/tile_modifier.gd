class_name TileModifier
extends RefCounted

# Player-applied tile modifier for future mechanics.
# This is not a Card or TileCard. TileCard occupies a hex as a playable piece.

var name: String
var description: String
var icon: Texture2D


static func can_apply_to(hex: Hex) -> bool:
	return not hex.is_disabled_by_difficulty


static func can_replace_on(hex: Hex) -> bool:
	if not can_apply_to(hex):
		return false
	return hex.tile_modifier == null
