class_name MineralData
extends Resource

enum NodeSize { SMALL, MEDIUM, LARGE }

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var description: String
# The base production rate is the amount of resource produced per turn
@export var base_production_rate: int
# NodeSize is used as a multiplier for the base production rate
# Example: SMALL = 1, MEDIUM = 2, LARGE = 3
# The base production rate is multiplied by the size to get the final production rate
@export var size: NodeSize = NodeSize.SMALL
# The rarity of the resource determines how common it is in the game world
# Rarity is a value between 1 and 5, where 1 is common and 5 is very rare
@export var rarity: int
