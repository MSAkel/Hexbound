class_name Ruins
extends Resource

@export var id: String
@export var ruins_name: String
@export var description: String
@export var icon: Texture2D
@export var cost: int
# should contain a list of potential rewards, each with a chance to be selected. some higher than the other
# example rewards:
# - gold
# - rune
# - perk
# - curse
# - no reward
