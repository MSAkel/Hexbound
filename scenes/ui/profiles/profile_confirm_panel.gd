class_name ProfileConfirmPanel
extends Control

## Modal yes / no for the profile panel (Delete, Unlock all). Each asks twice: the caller shows the
## second question from the first one's confirmed signal.

signal confirmed
signal cancelled

@onready var title_label: Label = %TitleLabel
@onready var description_label: Label = %DescriptionLabel
@onready var cancel_button: Button = %CancelButton
@onready var confirm_button: Button = %ConfirmButton


func _ready() -> void:
	hide()
	# Modal: directional focus must not wander to the slot cards behind the panel.
	MenuFocus.trap_row([cancel_button, confirm_button])


func ask(title: String, description: String, confirm_text: String) -> void:
	title_label.text = title
	description_label.text = description
	confirm_button.text = confirm_text
	show()
	move_to_front()
	cancel_button.grab_focus()


func cancel() -> void:
	if not visible:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	hide()
	cancelled.emit()


func _on_cancel_button_pressed() -> void:
	cancel()


func _on_confirm_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	hide()
	confirmed.emit()
