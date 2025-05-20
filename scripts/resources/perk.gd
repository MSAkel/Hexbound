class_name Perk
extends Resource

enum PerkRarity { COMMON, UNCOMMON, RARE, LEGENDARY }
enum Type {END_OF_TURN, START_OF_TURN, GOLD_EARNED, PASSIVE}

@export var id: String
@export var perk_name: String
@export var icon: Texture2D
@export var type: Type
@export var rarity: PerkRarity
@export_multiline var description: String
