class_name AbandonRunConfirmPanel
extends Control

signal confirmed
signal cancelled

@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	hide()
	# Modal: directional focus must not wander to the chef screen behind the panel.
	MenuFocus.trap_row([cancel_button, confirm_button])


func show_panel() -> void:
	show()
	move_to_front()
	cancel_button.grab_focus()


func hide_panel() -> void:
	hide()


func cancel() -> void:
	if not visible:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	hide_panel()
	cancelled.emit()


func _on_cancel_button_pressed() -> void:
	cancel()


func _on_confirm_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	hide_panel()
	confirmed.emit()
