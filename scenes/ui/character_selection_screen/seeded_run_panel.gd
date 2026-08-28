class_name SeededRunPanel
extends PanelContainer

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

@onready var seeded_run_toggle: CheckBox = %SeededRunToggle
@onready var unlocks_note_label: Label = %UnlocksNoteLabel
@onready var seed_input_row: HBoxContainer = %SeedInputRow
@onready var seed_input: LineEdit = %SeedInput
@onready var paste_seed_button: TextureButton = %PasteSeedButton


func _ready() -> void:
	seeded_run_toggle.toggled.connect(_on_seeded_run_toggled)
	seed_input.text_changed.connect(_on_seed_input_changed)
	seed_input.focus_exited.connect(_on_seed_input_focus_exited)
	paste_seed_button.tooltip_text = "Paste seed from clipboard"
	_update_seed_input_visibility()


func is_seeded_mode_enabled() -> bool:
	return seeded_run_toggle.button_pressed


func get_effective_seed_text() -> String:
	if not is_seeded_mode_enabled():
		return ""
	return RunRng.normalize_seed_text(seed_input.text)


## True only when the player entered a custom seed. Empty input still starts a normal run.
func uses_custom_seed() -> bool:
	return not get_effective_seed_text().is_empty()


func _on_seed_input_changed(_new_text: String) -> void:
	_update_unlocks_note_visibility()


func _on_seed_input_focus_exited() -> void:
	var normalized := RunRng.normalize_seed_text(seed_input.text)
	if seed_input.text == normalized:
		return
	seed_input.text = normalized
	_update_unlocks_note_visibility()


func _on_seeded_run_toggled(_toggled_on: bool) -> void:
	_update_seed_input_visibility()
	AudioManager.play_sfx(UI_SOUNDS.SELECT)


func _update_seed_input_visibility() -> void:
	var seeded_mode := is_seeded_mode_enabled()
	seed_input_row.visible = seeded_mode
	if seeded_mode:
		seed_input.grab_focus()
	_update_unlocks_note_visibility()


func _update_unlocks_note_visibility() -> void:
	unlocks_note_label.visible = uses_custom_seed()


func _on_paste_seed_button_pressed() -> void:
	_apply_seed_text(RunRng.read_seed_from_clipboard())


func _apply_seed_text(seed_text: String) -> void:
	if seed_text.is_empty():
		return

	# Paste should turn seeded mode on so the value is not ignored when Play is pressed.
	if not seeded_run_toggle.button_pressed:
		seeded_run_toggle.button_pressed = true
		_update_seed_input_visibility()

	seed_input.text = seed_text
	_update_unlocks_note_visibility()
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
