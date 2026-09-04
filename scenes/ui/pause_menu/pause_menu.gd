extends Control


@onready var pause_menu: Control = $"."
@onready var panel: Panel = $Panel
@onready var menu_items_container: VBoxContainer = $Panel/MenuItemsContainer
@onready var layout_passives_viewer: LayoutPassivesViewer = %LayoutPassivesViewer
# Sibling overlays under MainUI
@onready var main_ui: CanvasLayer = get_parent() as CanvasLayer
@onready var settings_container: PanelContainer = $"../SettingsContainer"
@onready var collection_screen: Panel = $"../Collection"
@onready var rune_selection_ui: Control = $"../RuneSelectionUI"
@onready var merchant: Control = $"../Merchant"
@onready var round_complete_screen: Control = $"../RoundCompleteScreen"
@onready var tile_map: HexTileMap = $"../../HexTileMap"


func _ready() -> void:
	# Keep the whole UI layer interactive while get_tree().paused is true.
	if main_ui != null:
		main_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	process_mode = Node.PROCESS_MODE_ALWAYS
	_prepare_overlay_panel(settings_container)
	_prepare_overlay_panel(collection_screen)
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
	call_deferred("_focus_pause_menu")


func _on_layout_passives_closed() -> void:
	_hide_layout_passives_viewer()


func _hide_layout_passives_viewer() -> void:
	layout_passives_viewer.hide()
	menu_items_container.show()
	EventBus.toggle_tooltip.emit(false, "")
	call_deferred("_focus_pause_menu")


func _on_settings_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_show_pause_overlay(settings_container)


func _on_settings_closed() -> void:
	_hide_pause_overlay(settings_container)
	call_deferred("_focus_pause_menu")


func _on_collection_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_show_pause_overlay(collection_screen)


func _on_collection_closed() -> void:
	_hide_pause_overlay(collection_screen)
	EventBus.toggle_tooltip.emit(false, "")
	call_deferred("_focus_pause_menu")


func _on_main_menu_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	# Skips the write when the run is mid-action so the last stable file is kept.
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
	_hide_pause_overlay(settings_container)
	_hide_pause_overlay(collection_screen)
	panel.show()
	_set_pause_menu_blocks_gameplay(true)
	pause_menu.show()
	get_tree().paused = true
	call_deferred("_focus_pause_menu")


func _focus_pause_menu() -> void:
	if not pause_menu.visible:
		return
	if not panel.visible:
		return
	if settings_container.visible:
		MenuFocus.grab_first(settings_container)
		return
	if collection_screen.visible:
		MenuFocus.grab_first(collection_screen)
		return
	if layout_passives_viewer.visible:
		MenuFocus.grab_first(layout_passives_viewer)
		return
	MenuFocus.grab_first(menu_items_container)


func _close_pause_menu() -> void:
	# Dismiss nested overlays so they cannot linger over gameplay.
	_hide_layout_passives_viewer()
	_hide_pause_overlay(settings_container)
	_hide_pause_overlay(collection_screen)
	panel.show()
	_set_pause_menu_blocks_gameplay(true)
	pause_menu.hide()
	get_tree().paused = false
	EventBus.tooltip_hover_refresh_requested.emit()


func _input(event: InputEvent) -> void:
	if event.is_action_pressed("pause_game"):
		_handle_pause_toggle()
	elif event.is_action_pressed("ui_cancel") and pause_menu.visible:
		_handle_pause_back()


func _handle_pause_toggle() -> void:
	if pause_menu.visible:
		_handle_pause_back()
		return
	if _is_pause_blocked():
		return
	tile_map.dismiss_hover_feedback()
	_open_pause_menu()


func _handle_pause_back() -> void:
	if layout_passives_viewer.visible:
		_hide_layout_passives_viewer()
		return
	if collection_screen.visible:
		_on_collection_closed()
		return
	# Settings handles its own ui_cancel while visible.
	if settings_container.visible:
		return
	_close_pause_menu()


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


func _prepare_overlay_panel(overlay_root: Control) -> void:
	overlay_root.process_mode = Node.PROCESS_MODE_ALWAYS
	_set_process_mode_recursive(overlay_root, Node.PROCESS_MODE_ALWAYS)


func _show_pause_overlay(overlay: Control) -> void:
	panel.hide()
	# Full-screen pause root sits above Settings in z-order. Do not steal overlay clicks.
	_set_pause_menu_blocks_gameplay(false)
	overlay.show()
	overlay.move_to_front()
	call_deferred("_focus_pause_menu")


func _hide_pause_overlay(overlay: Control) -> void:
	overlay.hide()
	panel.show()
	_set_pause_menu_blocks_gameplay(true)


func _set_pause_menu_blocks_gameplay(blocks: bool) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP if blocks else Control.MOUSE_FILTER_IGNORE


func _set_process_mode_recursive(root: Node, mode: Node.ProcessMode) -> void:
	root.process_mode = mode
	for child in root.get_children():
		_set_process_mode_recursive(child, mode)
