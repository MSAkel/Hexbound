class_name SegmentPassiveModifier
extends RefCounted

# Character segment passive stamped onto fixed map tiles at run start.
# These tiles are reserved and cannot receive applied TileModifiers.

enum Type {
	FIRST_ROW,
	FIRST_CIRCLE,
	CENTER_TILE,
}

# Map preview for segment passives
const FIRST_IN_SEGMENT = preload("uid://bd7vwhffd8iiy")
const FIRST_CIRCLE_TILE_PASSIVE = preload("uid://c8lewiayrer5i")
const CENTER_TILE_PASSIVE = preload("uid://t7e6ybgan3k")


# Character selection screen icons for segment passives
const FIRST_IN_SEGMENT_PREVIEW = preload("uid://bgj3xo0w2i6gx")
const ENCRICLER_SEGMENT_PREVIEW = preload("uid://cvymih6a8i2nq")
const SPIRALIST_SEGMENT_PREVIEW = preload("uid://bm1itbk7dbfiy")


var modifier_type: Type
var name: String
var description: String
var icon: Texture2D


static func segment_passives_data(character_type: PlayerCharacter.Type) -> Dictionary:
	match character_type:
		PlayerCharacter.Type.SURVEYOR:
			return {
				"modifier_type": Type.FIRST_ROW,
				"icon": FIRST_IN_SEGMENT,
				"icon_preview": FIRST_IN_SEGMENT_PREVIEW,
				"name": "First In segment",
				"description": "Production runes on the first plot of a segment have double production",
			}
		PlayerCharacter.Type.ENCIRCLER:
			return {
				"modifier_type": Type.FIRST_CIRCLE,
				"icon": FIRST_CIRCLE_TILE_PASSIVE,
				"icon_preview": ENCRICLER_SEGMENT_PREVIEW,
				"name": "Circle Passive",
				"description": "If the first rune on a circle segment is a support rune, the rune gains a 15% chance to trigger each prod rune on the same segment.",
			}
		PlayerCharacter.Type.SPIRALIST:
			return {
				"modifier_type": Type.CENTER_TILE,
				"icon": CENTER_TILE_PASSIVE,
				"icon_preview": SPIRALIST_SEGMENT_PREVIEW,
				"name": "Center Tile Passive",
				"description": "Rune in the center tile triggers thrice, including support runes.",
			}
		_:
			return segment_passives_data(PlayerCharacter.Type.SURVEYOR)


static func create_for_character(character_type: PlayerCharacter.Type) -> SegmentPassiveModifier:
	var config := segment_passives_data(character_type)
	var modifier := SegmentPassiveModifier.new()
	modifier.name = config["name"]
	modifier.description = config["description"]
	modifier.modifier_type = config["modifier_type"]
	modifier.icon = config["icon"]
	return modifier


static func get_display_name(character_type: PlayerCharacter.Type) -> String:
	return segment_passives_data(character_type)["name"]


static func get_description(character_type: PlayerCharacter.Type) -> String:
	return segment_passives_data(character_type)["description"]


static func get_icon_preview(character_type: PlayerCharacter.Type) -> Texture2D:
	return segment_passives_data(character_type)["icon_preview"]
