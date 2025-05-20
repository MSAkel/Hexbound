class_name Mineral
extends Resource

enum NodeSize { SMALL, MEDIUM, LARGE }
enum Type {BERRIES, STONE, WOOL, WOOD}

@export var id: String
@export var name: String
@export var type: Type
@export var icon: Texture2D
@export var base_production_rate: int # The base production rate is the amount of resource produced per turn
@export var size: NodeSize = NodeSize.SMALL # NodeSize is used as a multiplier for the base production rate
@export var rarity: int # The rarity of the resource determines how common it is in the game world
@export_multiline var description: String
