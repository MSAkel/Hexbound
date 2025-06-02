class_name Building
extends Resource

enum BuildingType { 
    MINE, 
    LIBRARY, 
    BANK,
    VAULT,
    OUTPOST,
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var type: BuildingType
@export var generation_amount: int
