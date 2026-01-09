class_name GoodType
extends RefCounted

enum Type {
	GOLD,
	FOOD,
	WOOD,
	STONE,
	FAVOR,
	INSIGHT,
	MINERALS,
}

# Maps enum Type to string ID (for file paths, dictionary keys, etc.)
const GOOD_IDS = {
	Type.GOLD: "gold",
	Type.FOOD: "food",
	Type.WOOD: "wood",
	Type.STONE: "stone",
	Type.FAVOR: "favor",
	Type.INSIGHT: "insight",
	Type.MINERALS: "minerals",
}

# Reverse lookup: maps string ID to enum Type (for O(1) lookup)
const ID_TO_TYPE = {
	"gold": Type.GOLD,
	"food": Type.FOOD,
	"wood": Type.WOOD,
	"stone": Type.STONE,
	"favor": Type.FAVOR,
	"insight": Type.INSIGHT,
	"minerals": Type.MINERALS,
}

static func get_good_id(type: Type) -> String:
	return GOOD_IDS[type]

static func get_type_from_id(good_id: String) -> Type:
	var lower_id = good_id.to_lower()
	if ID_TO_TYPE.has(lower_id):
		return ID_TO_TYPE[lower_id]
	# Return first enum value as fallback
	return Type.GOLD

static func get_default_goods_dict() -> Dictionary:
	# Returns a dictionary with all good types as keys, initialized to 0
	var dict = {}
	for good_id in ID_TO_TYPE.keys():
		dict[good_id] = 0
	return dict 
