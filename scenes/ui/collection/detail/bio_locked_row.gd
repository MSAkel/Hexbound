class_name CollectionBioLockedRow
extends PanelContainer

## The next bio part not unlocked yet: a lock, "Part N" and the chef level that unlocks it.

@onready var _label: Label = %Label
@onready var _line: Label = %Line


func setup(label: String, chef_level: int) -> void:
	if not is_node_ready():
		await ready
	_label.text = label
	_line.text = "Reach chef level %d to unlock" % chef_level
