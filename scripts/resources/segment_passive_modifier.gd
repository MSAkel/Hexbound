class_name SegmentPassiveModifier
extends RefCounted

# Character segment passive stamped onto fixed map tiles at run start.
# These tiles are reserved and cannot receive applied TileModifiers.

enum Type {
	FIRST_ROW,
	FIRST_CIRCLE,
	CENTER_TILE,
}

const ICON_FIRST_ROW := preload("res://assets/map/segment_icons/first_row_tile_passive.png")
const ICON_FIRST_CIRCLE := preload("res://assets/map/segment_icons/first_circle_tile_passive.png")
const ICON_CENTER_TILE := preload("res://assets/map/segment_icons/center_tile_passive.png")

var modifier_type: Type
var name: String
var description: String
var icon: Texture2D


static func create_for_character(character_type: PlayerCharacter.Type) -> SegmentPassiveModifier:
	var modifier := SegmentPassiveModifier.new()
	modifier.name = PlayerCharacter.get_segment_passive_name(character_type)
	modifier.description = PlayerCharacter.get_segment_passive_description(character_type)

	match character_type:
		PlayerCharacter.Type.SURVEYOR:
			modifier.modifier_type = Type.FIRST_ROW
			modifier.icon = ICON_FIRST_ROW
		PlayerCharacter.Type.ENCIRCLER:
			modifier.modifier_type = Type.FIRST_CIRCLE
			modifier.icon = ICON_FIRST_CIRCLE
		PlayerCharacter.Type.SPIRALIST:
			modifier.modifier_type = Type.CENTER_TILE
			modifier.icon = ICON_CENTER_TILE
		_:
			modifier.modifier_type = Type.FIRST_ROW
			modifier.icon = ICON_FIRST_ROW

	return modifier


static func get_icon_for_character(character_type: PlayerCharacter.Type) -> Texture2D:
	return create_for_character(character_type).icon
