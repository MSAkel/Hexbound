extends Control

const SOUNDTRACK = preload("res://scripts/soundtracks.gd")

# Subtle hover pop: slight grow + warm brighten
const HOVER_SCALE := Vector2(1.06, 1.06)
const HOVER_MODULATE := Color(1.2, 1.15, 1.05, 1.0)
const HOVER_DURATION := 0.12

@onready var menu_items_container: VBoxContainer = $MenuContainer/MenuItemsContainer
@onready var ui_sandbox_button: Button = $MenuContainer/MenuItemsContainer/UISandboxButton
@onready var passives_sandbox_button: Button = $MenuContainer/MenuItemsContainer/PassivesSandboxButton

# Tracks in-flight hover tweens so rapid enter/exit does not stack.
var _hover_tweens: Dictionary = {}
var _reset_confirm_dialog: ConfirmationDialog


func _ready() -> void:
	_apply_debug_sandbox_buttons()

	var music = SOUNDTRACK.get_music_for_scene(ScenePaths.MAIN_MENU)
	if music:
		AudioManager.play_music(music)

	for button in menu_items_container.get_children():
		if button is Button:
			_set_button_pivot(button)
			button.resized.connect(_on_button_resized.bind(button))
			button.mouse_entered.connect(_on_button_hover.bind(button))
			button.mouse_exited.connect(_on_button_unhover.bind(button))
			button.focus_entered.connect(_on_focus_entered)

	_setup_reset_confirm_dialog()


func _on_button_resized(button: Button) -> void:
	_set_button_pivot(button)


func _set_button_pivot(button: Button) -> void:
	# Mirroring the former centered pivot gives the same travel in reverse.
	button.pivot_offset = Vector2(-button.size.x / 2.0, button.size.y / 2.0)


func _on_button_hover(button: Button) -> void:
	AudioManager.play_ui_hover()
	_animate_button_hover(button, true)


func _on_button_unhover(button: Button) -> void:
	_animate_button_hover(button, false)


func _animate_button_hover(button: Button, hovered: bool) -> void:
	# Cancel any previous tween on this button so enters/exits stay snappy.
	if _hover_tweens.has(button):
		var previous: Tween = _hover_tweens[button]
		if previous.is_valid():
			previous.kill()

	_set_button_pivot(button)
	var tween := create_tween()
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_QUAD)
	tween.set_parallel(true)
	tween.tween_property(button, "scale", HOVER_SCALE if hovered else Vector2.ONE, HOVER_DURATION)
	tween.tween_property(button, "modulate", HOVER_MODULATE if hovered else Color.WHITE, HOVER_DURATION)
	_hover_tweens[button] = tween


func _on_focus_entered() -> void:
	AudioManager.play_ui_hover()


func _apply_debug_sandbox_buttons() -> void:
	var sandbox_buttons: Array[Button] = [ui_sandbox_button, passives_sandbox_button]
	var debug := OS.is_debug_build()
	for button in sandbox_buttons:
		if button == null:
			continue
		if debug:
			button.visible = true
		else:
			button.queue_free()


func _setup_reset_confirm_dialog() -> void:
	_reset_confirm_dialog = ConfirmationDialog.new()
	_reset_confirm_dialog.title = "Reset progression?"
	_reset_confirm_dialog.dialog_text = (
		"This resets all unlocks, layout XP, passive loadouts, lifetime stats, and run history. "
		+ "Your in-progress run save is also deleted. This cannot be undone."
	)
	_reset_confirm_dialog.ok_button_text = "Reset"
	_reset_confirm_dialog.cancel_button_text = "Cancel"
	_reset_confirm_dialog.initial_position = Window.WINDOW_INITIAL_POSITION_CENTER_MAIN_WINDOW_SCREEN
	add_child(_reset_confirm_dialog)
	_reset_confirm_dialog.confirmed.connect(_on_reset_progression_confirmed)


func _on_back_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _on_reset_progression_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	_reset_confirm_dialog.popup_centered()


func _on_reset_progression_confirmed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	MetaProgressionManager.reset_progression()
	RunHistoryManager.clear()
	RunSaveManager.delete_save()
	GameSettings.reset_progression_preferences()


func _on_ui_sandbox_button_pressed() -> void:
	if not OS.is_debug_build():
		return
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.UI_SANDBOX)


func _on_passives_sandbox_button_pressed() -> void:
	if not OS.is_debug_build():
		return
	AudioManager.play_sfx(UISounds.CLICK)
	get_tree().change_scene_to_file(ScenePaths.SEGMENT_PASSIVES_SANDBOX)
