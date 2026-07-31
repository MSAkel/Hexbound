extends Control

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

@onready var first_order_button: Button = $Panel/VBoxContainer/HBoxContainer/VBoxContainer/FirstOrderButton
@onready var second_order_button: Button = $Panel/VBoxContainer/HBoxContainer/VBoxContainer2/SecondOrderButton
@onready var third_order_button: Button = $Panel/VBoxContainer/HBoxContainer/VBoxContainer3/ThirdOrderButton


func _ready() -> void:
	hide()
	_refresh_button_states()
	Events.trigger_order_changed.connect(_refresh_button_states)


# Signal passes the new order; GameManager is the source of truth for button state.
func _refresh_button_states(_new_order: TriggerOrderType.Type = TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT) -> void:
	var active_order: TriggerOrderType.Type = GameManager.trigger_order
	first_order_button.text = "Active" if active_order == TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT else "Select"
	first_order_button.disabled = active_order == TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT
	second_order_button.text = "Active" if active_order == TriggerOrderType.Type.OUTER_RING_TO_INNER else "Select"
	second_order_button.disabled = active_order == TriggerOrderType.Type.OUTER_RING_TO_INNER
	third_order_button.text = "Active" if active_order == TriggerOrderType.Type.CLOCKWISE_SPIRAL else "Select"
	third_order_button.disabled = active_order == TriggerOrderType.Type.CLOCKWISE_SPIRAL


func _select_order(order: TriggerOrderType.Type) -> void:
	if GameManager.trigger_order == order:
		return
	GameManager.trigger_order = order
	AudioManager.play_ui_sound(UI_SOUNDS.SELECT)


func _on_first_order_button_pressed() -> void:
	_select_order(TriggerOrderType.Type.TOP_LEFT_TO_BOTTOM_RIGHT)


func _on_second_order_button_pressed() -> void:
	_select_order(TriggerOrderType.Type.OUTER_RING_TO_INNER)


func _on_third_order_button_pressed() -> void:
	_select_order(TriggerOrderType.Type.CLOCKWISE_SPIRAL)


func _on_close_button_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	hide()
