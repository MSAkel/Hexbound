class_name Objective
extends Resource

enum ObjectiveType {
	EXPLORE,
	BUILDING,
	RUNE,
	GENERATION,
	DELIVERY,
}

@export var requirement: String
@export var icon: Texture2D
@export var objective_type: ObjectiveType
@export var amount_required: int
var progress: int
var completed: bool

func cleanup() -> void:
	# Base cleanup method - override in child classes if needed
	pass