class_name GameSpeedUi
extends Control

const ACTIVE_TINT := Color(222.0 / 255.0, 222.0 / 255.0, 81.0 / 255.0)
const INACTIVE_TINT := Color.WHITE

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
