class_name MerchantPurchaseTray
extends HBoxContainer

## Compact buy controls shown beneath a selected merchant shelf item.

signal gold_purchase_pressed

@onready var _gold_button: Button = $GoldButton


func _on_gold_button_pressed() -> void:
	gold_purchase_pressed.emit()


func set_gold_enabled(enabled: bool) -> void:
	_gold_button.disabled = not enabled


## Buy buttons join the focus chain only while the tray is shown for a selected item.
## Otherwise directional navigation would stop on invisible controls.
func set_focusable(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	_gold_button.focus_mode = mode
	if not enabled and _gold_button.has_focus():
		_gold_button.release_focus()


## Grabs the buy button when the player can afford the item.
## False when gold purchase is disabled, so the caller can fall back elsewhere.
func focus_first_enabled() -> bool:
	if _gold_button.disabled or _gold_button.focus_mode == Control.FOCUS_NONE:
		return false
	_gold_button.grab_focus()
	return true
