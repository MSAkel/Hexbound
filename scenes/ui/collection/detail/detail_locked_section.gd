class_name CollectionDetailLockedSection
extends VBoxContainer

## A section that is not unlocked yet (The story, Fun facts): its heading, a lock, what unlocks it
## and a progress bar with the count. The hidden text itself is never shown.

@onready var _heading: Label = $Heading
@onready var _line: Label = %Line
@onready var _bar: ProgressBar = %Bar
@onready var _count: Label = %Count


func setup(heading: String, line: String, progress: int, goal: int) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading
	_line.text = line
	_bar.max_value = goal
	_bar.value = mini(progress, goal)
	_count.text = "%d / %d" % [mini(progress, goal), goal]
