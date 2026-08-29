extends Control


@onready var pause_menu: Control = $"."
@onready var panel: Panel = $Panel
@onready var menu_items_container: VBoxContainer = $Panel/MenuItemsContainer
@onready var layout_passives_viewer: LayoutPassivesViewer = %LayoutPassivesViewer
# Sibling overlays under MainUI
@onready var settings_container: PanelContainer = $"../SettingsContainer"
@onready var collection_screen: Panel = $"../Collection"
@onready var rune_selection_ui: Control = $"../RuneSelectionUI"
@onready var merchant: Control = $"../Merchant"
@onready var round_complete_screen: Control = $"../RoundCompleteScreen"
@onready var tile_map: HexTileMap = $"../../HexTileMap"


func _ready() -> void:
	# Keep pause UI interactive while the scene tree is frozen during turn resolution.
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings_container.process_mode = Node.PROCESS_MODE_ALWAYS
	collection_screen.process_mode = Node.PROCESS_MODE_ALWAYS
	# Restore pause buttons when settings Back is pressed
	settings_container.closed.connect(_on_settings_closed)
	if not collection_screen.closed.is_connected(_on_collection_closed):
		collection_screen.closed.connect(_on_collection_closed)
	if not layout_passives_viewer.closed.is_connected(_on_layout_passives_closed):
		layout_passives_viewer.closed.connect(_on_layout_passives_closed)


func _on_continue_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_close_pause_menu()


func _on_layout_passives_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	# Keep the dimmed pause backdrop. Swap the button list for the read-only map.
	menu_items_container.hide()
	layout_passives_viewer.show()


func _on_layout_passives_closed() -> void:
	_hide_layout_passives_viewer()


func _hide_layout_passives_viewer() -> void:
	layout_passives_viewer.hide()
	menu_items_container.show()
	EventBus.toggle_tooltip.emit(false, "")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	panel.hide()
	settings_container.show()


func _on_settings_closed() -> void:
	settings_container.hide()
	panel.show()


func _on_collection_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	panel.hide()
	collection_screen.show()


func _on_collection_closed() -> void:
	collection_screen.hide()
	panel.show()
	EventBus.toggle_tooltip.emit(false, "")


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	RunSaveManager.save_current_run()
	get_tree().paused = false
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _on_new_run_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	# Same as hold-R. Drops the current save and starts a new seed on this character.
	get_tree().paused = false
	var main := get_tree().current_scene
	if main != null and main.has_method("restart_run"):
		main.restart_run()


func _open_pause_menu() -> void:
	# Always reopen on the button list, not a leftover overlay.
	_hide_layout_passives_viewer()
	collection_screen.hide()
	settings_container.hide()
	panel.show()
	pause_menu.show()
	get_tree().paused = true


func _close_pause_menu() -> void:
	# Dismiss nested overlays so they cannot linger over gameplay.
	_hide_layout_passives_viewer()
	settings_container.hide()
	collection_screen.hide()
	panel.show()
	pause_menu.hide()
	get_tree().paused = false
	EventBus.tooltip_hover_refresh_requested.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		if pause_menu.visible:
			# Back out of nested overlays first, then close pause on the next press.
			if layout_passives_viewer.visible:
				_hide_layout_passives_viewer()
				return
			if collection_screen.visible:
				_on_collection_closed()
				return
			_close_pause_menu()
			return
		if _is_pause_blocked():
			return
		tile_map.dismiss_hover_feedback()
		_open_pause_menu()


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
