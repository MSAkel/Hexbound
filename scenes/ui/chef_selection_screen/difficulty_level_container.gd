class_name DifficultyLevelContainer
extends HBoxContainer

## Emitted when the shown level or its lock state changes, so the screen can enable Play.
signal selection_changed

## Locked levels stay browsable but show this text and dim the number (ChefProgression decides
## what is unlocked, per chef).
const LOCKED_INFO := "Locked. Win a run on Level %d with this chef to unlock."
const LOCKED_MODULATE := Color(1, 1, 1, 0.45)

@onready var difficulty_level: Label = %DifficultyLevel
@onready var difficulty_info: Label = %DifficultyInfo
@onready var number_box: Control = $DifficultyPanel/DifficultyCopy/NumberBox

# Ordered list used for prev/next navigation on the selection screen.
var _difficulties: Array[Difficulty.Level] = Difficulty.get_all_levels()
var _current_index: int = 0
var _chef_id := ""


func _ready() -> void:
	_update_display()


func get_selected_difficulty() -> Difficulty.Level:
	return _difficulties[_current_index]


func is_selected_unlocked() -> bool:
	return _chef_id.is_empty() or ChefProgression.is_difficulty_unlocked(_chef_id, int(get_selected_difficulty()))


## Shows the unlocks of this chef. A level the chef hasn't unlocked falls back to its highest
## unlocked level.
func set_chef(chef_id: String) -> void:
	_chef_id = chef_id
	_clamp_to_unlocked()
	_update_display()


func display_difficulty(level: Difficulty.Level) -> void:
	var index := _difficulties.find(level)
	if index < 0:
		return

	_current_index = index
	_clamp_to_unlocked()
	_update_display()


func _clamp_to_unlocked() -> void:
	if _chef_id.is_empty():
		return
	var highest := ChefProgression.highest_unlocked_difficulty(_chef_id)
	if int(_difficulties[_current_index]) > highest:
		var index := _difficulties.find(highest)
		_current_index = maxi(index, 0)


# Refresh the name and description labels for the current difficulty.
func _update_display() -> void:
	if not is_node_ready():
		return
	var level := _difficulties[_current_index]
	# The number box shows the level number only ("Level 3" -> "3").
	difficulty_level.text = str(_current_index + 1)
	var unlocked := is_selected_unlocked()
	difficulty_info.text = Difficulty.get_level_info(level) if unlocked else LOCKED_INFO % _current_index
	number_box.modulate = Color.WHITE if unlocked else LOCKED_MODULATE
	selection_changed.emit()


# Wrap to the last difficulty when moving past the start of the list.
func _on_prev_selection_button_pressed() -> void:
	_current_index = (_current_index - 1 + _difficulties.size()) % _difficulties.size()
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)


# Wrap to the first difficulty when moving past the end of the list.
func _on_next_selection_button_pressed() -> void:
	_current_index = (_current_index + 1) % _difficulties.size()
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)
