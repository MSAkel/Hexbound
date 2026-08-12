class_name SegmentPassiveModifier
extends RefCounted

# Character segment passive stamped onto fixed map tiles at run start.
# These tiles are reserved and cannot receive applied TileModifiers.

enum Type {
	FIRST_ROW,
	FIRST_CIRCLE,
	CENTER_TILE,
}


var modifier_type: Type
var name: String
var description: String
var icon: Texture2D


static func create_for_character(character: CharacterDefinition) -> SegmentPassiveModifier:
	var modifier := SegmentPassiveModifier.new()
	if character == null:
		return modifier

	modifier.name = character.passive_name
	modifier.description = character.passive_description
	modifier.modifier_type = character.passive_modifier_type
	modifier.icon = character.passive_icon
	return modifier
