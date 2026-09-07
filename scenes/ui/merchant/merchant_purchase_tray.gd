class_name MerchantPurchaseTray
extends HBoxContainer

## Compact buy controls shown beneath a selected merchant shelf item.

signal gold_purchase_pressed
signal token_purchase_pressed

@onready var _gold_button: Button = $GoldButton
@onready var _token_button: Button = $TokenButton


# Scene buttons forward to these so CardUI can emit purchase requests with a card identity.
func _on_gold_button_pressed() -> void:
	gold_purchase_pressed.emit()


func _on_token_button_pressed() -> void:
	token_purchase_pressed.emit()


func set_gold_enabled(enabled: bool) -> void:
	_gold_button.disabled = not enabled


func set_token_enabled(enabled: bool) -> void:
	_token_button.disabled = not enabled


## Buy buttons join the focus chain only while the tray is shown for a selected item.
## Otherwise directional navigation would stop on invisible controls.
func set_focusable(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button: Button in [_gold_button, _token_button]:
		button.focus_mode = mode
		if not enabled and button.has_focus():
			button.release_focus()


## Grabs the first buy button the player can actually press.
## False when both are disabled, so the caller can fall back elsewhere.
func focus_first_enabled() -> bool:
	for button: Button in [_gold_button, _token_button]:
		if button.disabled or button.focus_mode == Control.FOCUS_NONE:
			continue
		button.grab_focus()
		return true
	return false
