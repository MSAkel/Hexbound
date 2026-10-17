class_name MerchantPurchaseTray
extends HBoxContainer

## Compact buy controls shown beneath a selected merchant shelf item.

signal gold_purchase_pressed
signal lock_toggled(locked: bool)

@onready var _gold_button: Button = $GoldButton
@onready var _lock_button: Button = $LockButton


func _on_gold_button_pressed() -> void:
	gold_purchase_pressed.emit()


func _on_lock_button_toggled(locked: bool) -> void:
	lock_toggled.emit(locked)


## Mirrors the shelf item's lock state without re-emitting lock_toggled.
func set_locked(locked: bool) -> void:
	_lock_button.set_pressed_no_signal(locked)


const BUY_LABEL := "Buy"


func set_gold_enabled(enabled: bool) -> void:
	_gold_button.disabled = not enabled


## Replaces the Buy label with the reason the item cannot be bought. Empty restores it.
func set_block_reason(reason: String) -> void:
	_gold_button.text = BUY_LABEL if reason.is_empty() else reason


## Buy buttons join the focus chain only while the tray is shown for a selected item.
## Otherwise directional navigation would stop on invisible controls.
func set_focusable(enabled: bool) -> void:
	var mode := Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	for button: Button in [_gold_button, _lock_button]:
		button.focus_mode = mode
		if not enabled and button.has_focus():
			button.release_focus()


## Grabs the buy button when the player can afford the item, else the lock button.
## False when the tray is not focusable, so the caller can fall back elsewhere.
func focus_first_enabled() -> bool:
	if _gold_button.focus_mode == Control.FOCUS_NONE:
		return false
	if _gold_button.disabled:
		_lock_button.grab_focus()
	else:
		_gold_button.grab_focus()
	return true
