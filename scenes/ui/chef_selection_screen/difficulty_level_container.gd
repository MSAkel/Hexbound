class_name DifficultyLevelContainer
extends HBoxContainer

## Only unlocked levels can be shown (ChefProgression decides, per chef). The arrows stop at Level 1
## and at the chef's highest unlocked level instead of wrapping, and are disabled there.
const DISABLED_ARROW_MODULATE := Color(1, 1, 1, 0.35)

@onready var difficulty_level: Label = %DifficultyLevel
@onready var difficulty_info: Label = %DifficultyInfo
@onready var prev_button: TextureButton = $PrevSelectionButton
@onready var next_button: TextureButton = $NextSelectionButton

# Ordered list used for prev/next navigation on the selection screen.
var _difficulties: Array[Difficulty.Level] = Difficulty.get_all_levels()
var _current_index: int = 0
var _chef_id := ""


func _ready() -> void:
	_update_display()


func get_selected_difficulty() -> Difficulty.Level:
	return _difficulties[_current_index]


func is_selected_unlocked() -> bool:
	return _current_index <= _highest_index()


## Shows the unlocks of this chef. A level the chef hasn't unlocked falls back to its highest
## unlocked level.
func set_chef(chef_id: String) -> void:
	_chef_id = chef_id
	_current_index = mini(_current_index, _highest_index())
	_update_display()


func display_difficulty(level: Difficulty.Level) -> void:
	var index := _difficulties.find(level)
	if index < 0:
		return

	_current_index = mini(index, _highest_index())
	_update_display()


func _highest_index() -> int:
	if _chef_id.is_empty():
		return _difficulties.size() - 1
	return clampi(ChefProgression.highest_unlocked_difficulty(_chef_id), 0, _difficulties.size() - 1)


# Refresh the name and description labels for the current difficulty.
func _update_display() -> void:
	if not is_node_ready():
		return
	var level := _difficulties[_current_index]
	# The number box shows the level number only ("Level 3" -> "3").
	difficulty_level.text = str(_current_index + 1)
	difficulty_info.text = Difficulty.get_level_info(level)
	_set_arrow_enabled(prev_button, _current_index > 0)
	_set_arrow_enabled(next_button, _current_index < _highest_index())


func _set_arrow_enabled(button: TextureButton, enabled: bool) -> void:
	button.disabled = not enabled
	button.modulate = Color.WHITE if enabled else DISABLED_ARROW_MODULATE
	button.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE


func _on_prev_selection_button_pressed() -> void:
	if _current_index <= 0:
		return
	_current_index -= 1
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)


func _on_next_selection_button_pressed() -> void:
	if _current_index >= _highest_index():
		return
	_current_index += 1
	_update_display()
	AudioManager.play_sfx(UISounds.SELECT)
