extends HBoxContainer

signal prev_difficulty_level_pressed
signal next_difficulty_level_pressed

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var difficulty_level: Label = $DifficultyLevelPanel/MarginContainer/VBoxContainer/DifficultyLevel
@onready var difficulty_info: Label = $DifficultyLevelPanel/MarginContainer/VBoxContainer/DifficultyInfo
@onready var prev_button: TextureButton = $PrevSelection
@onready var next_button: TextureButton = $NextSelection

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


func _on_prev_selection_pressed() -> void:
	if _current_index <= 0:
		return

	_current_index -= 1
	_update_display()
	prev_difficulty_level_pressed.emit()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _on_next_selection_pressed() -> void:
	if _current_index >= _difficulties.size() - 1:
		return

	_current_index += 1
	_update_display()
	next_difficulty_level_pressed.emit()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


# Refresh the name and description labels for the current difficulty.
func _update_display() -> void:
	var level := _difficulties[_current_index]
	difficulty_level.text = Difficulty.get_level_name(level)
	difficulty_info.text = Difficulty.get_level_info(level)
	_update_navigation_buttons()


# Hide prev/next at the ends of the list instead of wrapping around.
func _update_navigation_buttons() -> void:
	prev_button.visible = _current_index > 0
	next_button.visible = _current_index < _difficulties.size() - 1
