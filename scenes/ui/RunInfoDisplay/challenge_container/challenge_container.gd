extends Control

@onready var next_challenge_phase: Label = $ChallengePanel/VBoxContainer/NextChallengePhase
@onready var challenge_name: Label = $ChallengePanel/VBoxContainer/ChallengeName
@onready var challenge_description: Label = $ChallengePanel/VBoxContainer/ChallengeDescription
@onready var challenge_panel: PanelContainer = $ChallengePanel

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	Events.phase_changed.connect(_update_challenge_preview)
	Events.challenge_schedule_changed.connect(_update_challenge_preview)
	Events.challenge_changed.connect(_update_challenge_preview)

	challenge_panel.mouse_entered.connect(_on_mouse_entered)
	challenge_panel.mouse_exited.connect(_on_mouse_exited)

	_update_challenge_preview()


func _update_challenge_preview(_new_phase: int = -1) -> void:
	# Keep showing the active challenge name until its phase completes.
	if ChallengeManager.active_challenge != -1:
		challenge_name.text = ChallengeManager.get_challenge_name(ChallengeManager.active_challenge)
		return

	var next_phase := ChallengeManager.get_next_challenge_phase()
	if next_phase == -1:
		next_challenge_phase.text = "None"
		challenge_name.text = ""
		challenge_description.text = ""
		return

	var next_challenge := ChallengeManager.get_next_challenge_type()
	next_challenge_phase.text = "Phase %s" % next_phase
	if next_challenge == -1:
		challenge_name.text = ""
		challenge_description.text = ""
	else:
		challenge_name.text = ChallengeManager.get_challenge_name(next_challenge)
		challenge_description.text = ChallengeManager.get_challenge_description(next_challenge)


func _get_tooltip_text() -> String:
	if ChallengeManager.active_challenge != -1:
		var phase := GameManager.current_phase
		var description := ChallengeManager.get_challenge_description(ChallengeManager.active_challenge)
		return "Phase %d\n%s" % [phase, description]

	var next_phase := ChallengeManager.get_next_challenge_phase()
	if next_phase == -1:
		return ""

	var next_challenge := ChallengeManager.get_next_challenge_type()
	if next_challenge == -1:
		return ""

	return "Phase %d\n%s" % [next_phase, ChallengeManager.get_challenge_description(next_challenge)]


func _get_tooltip_rect() -> Rect2:
	return challenge_panel.get_global_rect()


func _on_mouse_entered() -> void:
	var text := _get_tooltip_text()
	if text.is_empty():
		return
	Events.toggle_tooltip.emit(true, text, _get_tooltip_rect())


func _on_mouse_exited() -> void:
	Events.toggle_tooltip.emit(false, "")
