class_name PerkData
extends Resource

enum PerkRarity { COMMON, UNCOMMON, RARE, LEGENDARY }

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var description: String
@export var rarity: PerkRarity
