class_name SeededRunPanel
extends PanelContainer


@onready var seeded_run_toggle: CheckBox = %SeededRunToggle
@onready var seeded_run_label: Label = %SeededRunLabel
@onready var unlocks_note_label: Label = %UnlocksNoteLabel
@onready var seed_input_row: HBoxContainer = %SeedInputRow
@onready var seed_input: LineEdit = %SeedInput


func _ready() -> void:
	seeded_run_toggle.toggled.connect(_on_seeded_run_toggled)
	seed_input.focus_exited.connect(_on_seed_input_focus_exited)
	# Label is separate from the checkbox so hover cannot restyle or clip the text.
	seeded_run_label.gui_input.connect(_on_seeded_run_label_gui_input)
	_update_seed_body_visibility()


func _on_seeded_run_label_gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		seeded_run_toggle.button_pressed = not seeded_run_toggle.button_pressed
		seeded_run_label.accept_event()


func is_seeded_mode_enabled() -> bool:
	return seeded_run_toggle.button_pressed


func get_effective_seed_text() -> String:
	if not is_seeded_mode_enabled():
		return ""
	return RunRng.normalize_seed_text(seed_input.text)


## True only when the player entered a custom seed. Empty input still starts a normal run.
func uses_custom_seed() -> bool:
	return not get_effective_seed_text().is_empty()


func _on_seed_input_focus_exited() -> void:
	var normalized := RunRng.normalize_seed_text(seed_input.text)
	if seed_input.text == normalized:
		return
	seed_input.text = normalized


func _on_seeded_run_toggled(_toggled_on: bool) -> void:
	_update_seed_body_visibility()
	AudioManager.play_sfx(UISounds.SELECT)


# Seeded mode swaps the unlocks note for the seed field and paste button.
func _update_seed_body_visibility() -> void:
	var seeded_mode := is_seeded_mode_enabled()
	seed_input_row.visible = seeded_mode
	unlocks_note_label.visible = not seeded_mode
	if seeded_mode:
		seed_input.grab_focus()


func _on_paste_seed_button_pressed() -> void:
	_apply_seed_text(RunRng.read_seed_from_clipboard())


func _apply_seed_text(seed_text: String) -> void:
	if seed_text.is_empty():
		return

	# Paste should turn seeded mode on so the value is not ignored when Play is pressed.
	if not seeded_run_toggle.button_pressed:
		seeded_run_toggle.button_pressed = true
		_update_seed_body_visibility()

	seed_input.text = seed_text
	AudioManager.play_sfx(UISounds.CLICK)
