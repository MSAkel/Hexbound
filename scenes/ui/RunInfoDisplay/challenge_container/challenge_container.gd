extends Control

@onready var next_challenge_phase: Label = $ChallengePanel/VBoxContainer/NextChallengePhase
@onready var challenge_name: Label = $ChallengePanel/VBoxContainer/ChallengeName
@onready var challenge_description: Label = $ChallengePanel/VBoxContainer/ChallengeDescription

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	Events.phase_changed.connect(_update_challenge_preview)
	Events.challenge_schedule_changed.connect(_update_challenge_preview)
	Events.challenge_changed.connect(_update_challenge_preview)

	_update_challenge_preview()

func _update_challenge_preview(_new_phase: int = -1) -> void:
	var next_phase := ChallengeManager.get_next_challenge_phase()
	if next_phase == -1:
		next_challenge_phase.text = "None"
		challenge_name.text = ""
		challenge_description.text = ""
		return

	var next_challenge := ChallengeManager.get_next_challenge_type()
	next_challenge_phase.text = "Phase %s" % next_phase
	challenge_name.text = ChallengeManager.get_challenge_name(next_challenge)
	if next_challenge == -1:
		challenge_description.text = ""
		challenge_name.text = ""
	else:
		challenge_description.text = ChallengeManager.get_challenge_description(next_challenge)
		challenge_name.text = ChallengeManager.get_challenge_name(next_challenge)

	if ChallengeManager.active_challenge != -1:
		challenge_description.text = ChallengeManager.get_challenge_description(
			ChallengeManager.active_challenge
		)
