extends Control

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

@onready var pause_menu: Control = $"."
@onready var panel: Panel = $Panel
# Sibling settings instance under MainUI
@onready var settings_container: PanelContainer = $"../SettingsContainer"
@onready var rune_selection_ui: Control = $"../RuneSelectionUI"
@onready var merchant: Control = $"../Merchant"
@onready var round_complete_screen: Control = $"../RoundCompleteScreen"
@onready var tile_map: HexTileMap = $"../../HexTileMap"


func _ready() -> void:
	# Restore pause buttons when settings Back is pressed
	settings_container.closed.connect(_on_settings_closed)


func _on_continue_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_close_pause_menu()


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	panel.hide()
	settings_container.show()


func _on_settings_closed() -> void:
	settings_container.hide()
	panel.show()


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RunSaveManager.save_current_run()
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")


func _on_exit_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	RunSaveManager.save_current_run()
	get_tree().quit()


func _close_pause_menu() -> void:
	# Dismiss settings too so it cannot linger over gameplay.
	settings_container.hide()
	panel.show()
	pause_menu.hide()
	EventBus.tooltip_hover_refresh_requested.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if pause_menu.visible:
			_close_pause_menu()
			return
		if _is_pause_blocked():
			return
		tile_map.dismiss_hover_feedback()
		pause_menu.show()


## Prevent the pause menu from opening on top of gameplay panels that require the player's attention.
func _is_pause_blocked() -> bool:
	return (
		_is_control_visible(rune_selection_ui)
		or _is_control_visible(merchant)
		or _is_control_visible(round_complete_screen)
	)


## Safely checks visibility because a referenced panel may be absent or already being freed.
func _is_control_visible(control: Control) -> bool:
	return is_instance_valid(control) and control.is_visible_in_tree()
