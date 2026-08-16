extends Control

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $VBoxContainer/TurnsContainer/TurnCounterLabel
@onready var required_score: Label = $VBoxContainer/RequiredScoreContainer/RequiredScore
@onready var score_this_round: Label = $VBoxContainer/ScoreContainer/ScoreThisRound
@onready var next_perk_counter: Label = $VBoxContainer/NextPerkCounter

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	required_score.text = "%s" % [GameManager.required_score]

	EventBus.turn_changed.connect(_update_turn_label)
	EventBus.total_round_score_changed.connect(_update_total_round_score)
	EventBus.required_score_changed.connect(_update_required_score)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.rune_activated.connect(_update_total_rune_activations)

func _on_end_turn_button_pressed() -> void:
	EventBus.turn_ended.emit()
	AudioManager.play_sfx(UI_SOUNDS.END_TURN)

func _on_turn_started() -> void:
	_update_round_label()

func _update_round_label() -> void:
	round_label.text = "Round %s" % [GameManager.current_round]

func _update_turn_label() -> void:
	turn_counter_label.text = "%s" % [GameManager.remaining_turns]

func _update_total_round_score() -> void:
	score_this_round.text = "%s" % [GameManager.total_round_score]

func _update_required_score() -> void:
	required_score.text = "%s" % [GameManager.required_score]

func _update_total_rune_activations(_rune: Rune) -> void:
	next_perk_counter.text = "%s" % [GameManager.rune_activations_countdown()]
