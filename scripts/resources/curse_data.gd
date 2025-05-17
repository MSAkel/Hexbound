class_name CurseData
extends Resource

enum severity { LOW, MEDIUM, HIGH }

@export var id: String
@export var curse_effect: String
@export var curse_effect_description: String
@export var icon: Texture2D
@export var curse_timer: int # in seconds
@export var curse_effect_icon: Texture2D
@export var curse_effect_severity: severity
@export var active: bool = false
