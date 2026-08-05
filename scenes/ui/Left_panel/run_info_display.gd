class_name TopPanelUi
extends Control

@onready var phase_label: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/PhaseAndTurnContainer/PhaseLabel
@onready var turn_label: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/PhaseAndTurnContainer/TurnLabel
@onready var required_score: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/RequiredScoreContainer/RequiredScore

@onready var turn_score: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/ScoreContainer/TurnScoreContainer/TurnScore
@onready var turn_mult: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/ScoreContainer/TurnScoreContainer/TurnMult

@onready var score_this_round: Label = $HBoxContainer/LeftContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/ScoreContainer/ScoreThisRound

@onready var next_challenge_phase: Label = $HBoxContainer/RightContainer/VBoxContainer/ChallengePanel/MarginContainer/VBoxContainer/NextChallengePhase
@onready var challenge_name: Label = $HBoxContainer/RightContainer/VBoxContainer/ChallengePanel/MarginContainer/VBoxContainer/ChallengeName
@onready var challenge_description: Label = $HBoxContainer/RightContainer/VBoxContainer/ChallengePanel/MarginContainer/VBoxContainer/ChallengeDescription


const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	required_score.text = "%s" % [GameManager.required_score]

	Events.turn_changed.connect(_update_turn_label)
	Events.turn_score_changed.connect(_update_turn_score)
	Events.turn_multi_changed.connect(_update_turn_multi)
	Events.total_score_changed.connect(_update_total_score)
	Events.required_score_changed.connect(_update_required_score)
	Events.turn_started.connect(_on_turn_started)
	Events.phase_changed.connect(_update_challenge_preview)
	Events.challenge_schedule_changed.connect(_update_challenge_preview)
	Events.challenge_changed.connect(_update_challenge_preview)

	_update_challenge_preview()

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

func _on_turn_started() -> void:
	_update_phase_label()

func _update_phase_label() -> void:
	phase_label.text = "Phase: %s" % [GameManager.current_phase]

func _update_turn_label() -> void:
	turn_label.text = "Turn: %s/%s" % [
		GameManager.current_turn,
		GameManager.get_max_turns_per_phase(),
	]


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

func _update_turn_score() -> void:
	turn_score.text = "%s" % [GameManager.turn_score]

func _update_turn_multi() -> void:
	turn_mult.text = "%s" % [GameManager.turn_multi]

func _update_total_score() -> void:
	score_this_round.text = "%s" % [GameManager.total_score]

func _update_required_score() -> void:
	required_score.text = "%s" % [GameManager.required_score]
