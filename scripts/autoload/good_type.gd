# What is this for?
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

const GOOD_IDS = {
	Type.GOLD: "gold",
	Type.FOOD: "food",
	Type.WOOD: "wood",
	Type.STONE: "stone",
	Type.FAVOR: "favor",
	Type.INSIGHT: "insight",
	Type.MINERALS: "minerals",
}

static func get_good_id(type: Type) -> String:
	return GOOD_IDS[type] 
