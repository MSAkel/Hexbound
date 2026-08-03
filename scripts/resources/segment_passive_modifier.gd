class_name SegmentPassiveModifier
extends RefCounted

# Character segment passive stamped onto fixed map tiles at run start.
# These tiles are reserved and cannot receive applied TileModifiers.

enum Type {
	FIRST_ROW,
	FIRST_CIRCLE,
	CENTER_TILE,
}

const SURVEYOR_SEGMENT_PASSIVE_MAP = preload("uid://bas7sbrvyj4fr")
const ENCRICLER_SEGMENT_PASSIVE_MAP = preload("uid://cvymih6a8i2nq")
const SPIRALIST_SEGMENT_PASSIVE_MAP = preload("uid://bm1itbk7dbfiy")

const FIRST_CIRCLE_TILE_PASSIVE = preload("uid://c8lewiayrer5i")
const FIRST_ROW_TILE_PASSIVE = preload("uid://bd7vwhffd8iiy")
const CENTER_TILE_PASSIVE = preload("uid://t7e6ybgan3k")

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
			modifier.icon = FIRST_ROW_TILE_PASSIVE
		PlayerCharacter.Type.ENCIRCLER:
			modifier.modifier_type = Type.FIRST_CIRCLE
			modifier.icon = FIRST_CIRCLE_TILE_PASSIVE
		PlayerCharacter.Type.SPIRALIST:
			modifier.modifier_type = Type.CENTER_TILE
			modifier.icon = CENTER_TILE_PASSIVE
		_:
			modifier.modifier_type = Type.FIRST_ROW
			modifier.icon = FIRST_ROW_TILE_PASSIVE

	return modifier


# Full-map preview textures for character selection UI.
static func get_map_texture_for_character(character_type: PlayerCharacter.Type) -> Texture2D:
	match character_type:
		PlayerCharacter.Type.SURVEYOR:
			return SURVEYOR_SEGMENT_PASSIVE_MAP
		PlayerCharacter.Type.ENCIRCLER:
			return ENCRICLER_SEGMENT_PASSIVE_MAP
		PlayerCharacter.Type.SPIRALIST:
			return SPIRALIST_SEGMENT_PASSIVE_MAP
		_:
			return SURVEYOR_SEGMENT_PASSIVE_MAP


# Small tile overlay icons shown on the in-game hex map.
static func get_icon_for_character(character_type: PlayerCharacter.Type) -> Texture2D:
	return create_for_character(character_type).icon
