class_name DifficultyLevelContainer
extends HBoxContainer


@onready var difficulty_level: Label = %DifficultyLevel
@onready var difficulty_info: Label = %DifficultyInfo

# Ordered list used for prev/next navigation on the selection screen.
var _difficulties: Array[Difficulty.Level] = Difficulty.get_all_levels()
var _current_index: int = 0


func _ready() -> void:
	_update_display()


func get_selected_difficulty() -> Difficulty.Level:
	return _difficulties[_current_index]


func display_difficulty(level: Difficulty.Level) -> void:
	var index := _difficulties.find(level)
	if index < 0:
		return

	_current_index = index
	_update_display()


# Refresh the name and description labels for the current difficulty.
func _update_display() -> void:
	var level := _difficulties[_current_index]
	difficulty_level.text = Difficulty.get_level_name(level)
	difficulty_info.text = Difficulty.get_level_info(level)


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
