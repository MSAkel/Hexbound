class_name ProfilePanel
extends Control

## Main menu profile screen: three slot cards (ProfileSlotCard). Select switches the active profile
## (ProfileManager.switch_to); Delete and Unlock all each ask twice. Main menu only.

signal closed

@onready var slot_row: HBoxContainer = %SlotRow
@onready var close_button: Button = %CloseButton
@onready var confirm_panel: ProfileConfirmPanel = %ProfileConfirmPanel

## What the confirm panel is asking: "delete" or "unlock", the slot, and which of the two asks.
var _pending_action := ""
var _pending_slot := 0
var _pending_step := 0


func _ready() -> void:
	add_to_group(InputManager.MENU_GROUP)
	visibility_changed.connect(_on_visibility_changed)
	confirm_panel.confirmed.connect(_on_confirmed)
	confirm_panel.cancelled.connect(_on_confirm_cancelled)
	ProfileManager.profile_changed.connect(func(_slot: int) -> void: _refresh())
	ProfileManager.summary_changed.connect(func(_slot: int) -> void: _refresh())
	var index := 1
	for card: ProfileSlotCard in _cards():
		card.slot = index
		index += 1
		card.select_pressed.connect(_on_select_pressed)
		card.delete_pressed.connect(_on_delete_pressed)
		card.unlock_all_pressed.connect(_on_unlock_all_pressed)


func _cards() -> Array[ProfileSlotCard]:
	var cards: Array[ProfileSlotCard] = []
	for child in slot_row.get_children():
		if child is ProfileSlotCard:
			cards.append(child as ProfileSlotCard)
	return cards


func _on_visibility_changed() -> void:
	if visible:
		_refresh()
		focus_default.call_deferred()


## InputManager menu hook. The confirm panel's Cancel while it is open, else the active card.
func focus_default() -> void:
	if not visible:
		return
	if confirm_panel.visible:
		confirm_panel.cancel_button.grab_focus()
		return
	for card: ProfileSlotCard in _cards():
		if card.slot == ProfileManager.active_slot and MenuFocus.grab_first(card) != null:
			return
	close_button.grab_focus()


func _refresh() -> void:
	if not visible:
		return
	for card: ProfileSlotCard in _cards():
		card.refresh()


func _unhandled_input(event: InputEvent) -> void:
	if not visible or not event.is_action_pressed("ui_cancel"):
		return
	get_viewport().set_input_as_handled()
	if confirm_panel.visible:
		confirm_panel.cancel()
	else:
		_on_close_button_pressed()


func _on_close_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()


func _on_select_pressed(slot: int) -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	ProfileManager.switch_to(slot)
	focus_default.call_deferred()


func _on_delete_pressed(slot: int) -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_ask("delete", slot, 1)


func _on_unlock_all_pressed(slot: int) -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_ask("unlock", slot, 1)


func _ask(action: String, slot: int, step: int) -> void:
	_pending_action = action
	_pending_slot = slot
	_pending_step = step
	if action == "delete":
		if step == 1:
			confirm_panel.ask("Delete Profile %d?" % slot,
				"Chef levels, unlocks, stats and the run in progress are lost.", "Delete")
		else:
			confirm_panel.ask("Are you sure?", "Profile %d can't be brought back." % slot, "Delete")
	elif step == 1:
		confirm_panel.ask("Unlock everything on Profile %d?" % slot,
			"Steam achievements are turned off for this profile.", "Unlock all")
	else:
		confirm_panel.ask("Are you sure?",
			"This can't be undone; only deleting the profile clears it.", "Unlock all")


func _on_confirmed() -> void:
	if _pending_step == 1:
		_ask(_pending_action, _pending_slot, 2)
		return
	if _pending_action == "delete":
		ProfileManager.delete_slot(_pending_slot)
	elif _pending_action == "unlock" and _pending_slot == ProfileManager.active_slot:
		ProfileManager.set_unlock_all()
	_clear_pending()
	_refresh()
	focus_default.call_deferred()


func _on_confirm_cancelled() -> void:
	_clear_pending()
	focus_default.call_deferred()


func _clear_pending() -> void:
	_pending_action = ""
	_pending_slot = 0
	_pending_step = 0
