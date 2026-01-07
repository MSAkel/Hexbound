class_name Rune
extends Resource

enum RuneRarity { 
	COMMON, 
	UNCOMMON, 
	RARE, 
	LEGENDARY 
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var selected: bool
@export var rarity: RuneRarity
@export var trigger_cost: Dictionary = {
	"gold": 0,
	"favor": 0,
	"insight": 0,
	"minerals": 0,
}

# func get_trigger_cost_text() -> String:
#     var text = ""
#     for good in trigger_cost:
#         text += "%s: %d\n" % [good, trigger_cost[good]]
#     return text

func activate_rune(tile: Hex) -> void:
	if tile.active_building.passive:
		return
