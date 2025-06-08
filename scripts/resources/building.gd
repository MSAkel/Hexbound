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
@export var type: BuildingType
@export var generation_amount: int
@export var generated_good: Good
@export var passive: bool = false
@export_multiline var description: String
@export_multiline var tooltip: String

var temporary_boost: int = 0

func trigger_building() -> void:
    # if a building is passive, it will be activated once and not triggered by runes
    if passive:
        return


func get_tooltip() -> String:
    return tooltip


func reset_temporary_boost() -> void:
    temporary_boost = 0

func activate_passive() -> void:
    pass