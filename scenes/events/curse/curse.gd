class_name Curse
extends Resource

enum severity { LOW, MEDIUM, HIGH }

@export var id: String
@export var curse_name: String
@export var curse_effect_description: String
@export var icon: Texture2D
@export var curse_timer: int # turns
@export var curse_effect_icon: Texture2D
@export var curse_effect_severity: severity
@export var active: bool = false
