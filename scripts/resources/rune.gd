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

func activate_rune(tile: Hex) -> void:
	if tile.active_building.passive:
		return
