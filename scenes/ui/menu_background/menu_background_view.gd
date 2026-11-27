extends Control

## The main menu's backdrop (drifting cover art under a dim layer) for the other menu screens.

@onready var _drift_material: ShaderMaterial = $ClipRoot/Background.material


func _process(_delta: float) -> void:
	# One shared clock, so the art does not jump when the screen changes.
	_drift_material.set_shader_parameter("motion_time", MenuBackground.get_motion_time())
