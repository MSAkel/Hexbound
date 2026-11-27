class_name CollectionSignatureCardLocked
extends PanelContainer

## A signature card slot whose chef level is not reached: an empty frame with "?" and the level.
## Its name and effect are never shown.

@onready var _level: Label = %Level


func setup(chef_level: int) -> void:
	if not is_node_ready():
		await ready
	_level.text = "Chef level %d" % chef_level
