class_name BuildingData
extends Resource

enum BuildingType { FARM, WAREHOUSE, MINE, WINDMILL }

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var type: BuildingType