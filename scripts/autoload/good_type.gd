class_name GoodType
extends RefCounted

enum Type {
	GOLD,
	FAVOR,
	INSIGHT,
	MINERALS,
}

# const GOOD_PATHS = {
# 	Type.GOLD: "res://resources/goods/gold.tres",
# 	Type.FAVOR: "res://resources/goods/favor.tres",
# 	Type.INSIGHT: "res://resources/goods/insight.tres"
# }

const GOOD_IDS = {
	Type.GOLD: "gold",
	Type.FAVOR: "favor",
	Type.INSIGHT: "insight",
	Type.MINERALS: "minerals",
}

# static func get_good_path(type: Type) -> String:
# 	return GOOD_PATHS[type]

static func get_good_id(type: Type) -> String:
	return GOOD_IDS[type] 
