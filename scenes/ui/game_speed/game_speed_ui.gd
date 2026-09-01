class_name GameSpeedUi
extends Control

const ACTIVE_TINT := Color(222.0 / 255.0, 222.0 / 255.0, 81.0 / 255.0)
const INACTIVE_TINT := Color.WHITE

const TOOLTIP_SPEED_1 := "Normal game speed."
const TOOLTIP_SPEED_2 := "Double game speed."
const TOOLTIP_SPEED_3 := "Triple game speed."

@onready var regular_game_speed_button: TextureButton = $RegularGameSpeedButton
@onready var double_game_speed_button: TextureButton = $DoubleGameSpeedButton
@onready var triple_game_speed_button: TextureButton = $TripleGameSpeedButton

var _speed_buttons: Array[TextureButton] = []


func _ready() -> void:
	_speed_buttons = [
		regular_game_speed_button,
		double_game_speed_button,
		triple_game_speed_button,
	]
	GameManager.game_speed_changed.connect(_update_active_tint)
	_update_active_tint(GameManager.game_speed)
	_bind_speed_tooltips()


func _bind_speed_tooltips() -> void:
	_bind_tooltip(regular_game_speed_button, TOOLTIP_SPEED_1)
	_bind_tooltip(double_game_speed_button, TOOLTIP_SPEED_2)
	_bind_tooltip(triple_game_speed_button, TOOLTIP_SPEED_3)


func _bind_tooltip(button: TextureButton, text: String) -> void:
	if button == null:
		return
	button.mouse_entered.connect(_show_speed_tooltip.bind(button, text))
	button.mouse_exited.connect(_hide_speed_tooltip)


func _show_speed_tooltip(button: TextureButton, text: String) -> void:
	EventBus.toggle_tooltip.emit(true, text, button.get_global_rect())


func _hide_speed_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _update_active_tint(speed: float) -> void:
	var active_index := int(speed) - 1
	for i in _speed_buttons.size():
		_speed_buttons[i].modulate = ACTIVE_TINT if i == active_index else INACTIVE_TINT


func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)


func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)


func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)
