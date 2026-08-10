extends Control

@onready var phase_label: Label = $VBoxContainer/PhaseLabel
@onready var turn_counter_label: Label = $VBoxContainer/TurnsContainer/TurnCounterLabel
@onready var required_score: Label = $VBoxContainer/RequiredScoreContainer/RequiredScore
@onready var score_this_round: Label = $VBoxContainer/ScoreContainer/ScoreThisRound

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	required_score.text = "%s" % [GameManager.required_score]

	Events.turn_changed.connect(_update_turn_label)
	Events.total_round_score_changed.connect(_update_total_round_score)
	Events.required_score_changed.connect(_update_required_score)
	Events.turn_started.connect(_on_turn_started)

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_sfx(UI_SOUNDS.END_TURN)

func _on_turn_started() -> void:
	_update_phase_label()

func _update_phase_label() -> void:
	phase_label.text = "Phase %s" % [GameManager.current_phase]

func _update_turn_label() -> void:
	turn_counter_label.text = "%s" % [GameManager.current_turn]

func _update_total_round_score() -> void:
	score_this_round.text = "%s" % [GameManager.total_round_score]

func _update_required_score() -> void:
	required_score.text = "%s" % [GameManager.required_score]
