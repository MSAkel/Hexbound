class_name RuneData
extends Resource

enum RuneRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var description: String
@export var selected: bool
@export var rarity: RuneRarity
