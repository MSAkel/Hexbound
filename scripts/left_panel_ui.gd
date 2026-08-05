class_name TopPanelUi
extends Control

@onready var character_name: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CharacterName
@onready var phase_label: Label = $Panel/MarginContainer/VBoxContainer/PhaseLabel
@onready var turn_label: Label = $Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var required_score: Label = $Panel/MarginContainer/VBoxContainer/RequiredScorePanel/RequiredScore
@onready var turn_score: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TurnScoreContainer/TurnScore
@onready var turn_multi: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TurnScoreContainer/TurnMulti
@onready var total_score: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TotalScore
@onready var selected_trigger_order_label: Label = $Panel/MarginContainer/VBoxContainer/SelectedTriggerOrderLabel
@onready var end_turn_button: Button = $Panel/MarginContainer/VBoxContainer/EndTurnButton

@onready var triggers_counter_label: Label = $Panel/MarginContainer/VBoxContainer/TriggersCounterLabel
@onready var challenge_description: Label = $Panel/MarginContainer/VBoxContainer/ChallengePanel/MarginContainer/VBoxContainer/ChallengeDescription
@onready var next_challenge_phase: Label = $Panel/MarginContainer/VBoxContainer/ChallengePanel/MarginContainer/VBoxContainer/NextChallengePhase


const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	required_score.text = "%s" % [GameManager.required_score]
	character_name.text = PlayerCharacter.get_character_name(GameManager.selected_character)
	_update_trigger_order_label()
	
	Events.turn_changed.connect(_update_turn_label)
	Events.turn_score_changed.connect(_update_turn_score)
	Events.turn_multi_changed.connect(_update_turn_multi)
	Events.total_score_changed.connect(_update_total_score)
	Events.required_score_changed.connect(_update_required_score)
	Events.turn_started.connect(_on_turn_started)
	Events.rune_activated.connect(_on_rune_activated)
	Events.phase_changed.connect(_update_challenge_preview)
	Events.challenge_schedule_changed.connect(_update_challenge_preview)
	Events.challenge_changed.connect(_update_challenge_preview)

	_update_challenge_preview()

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)
	end_turn_button.disabled = true

func _on_turn_started() -> void:
	end_turn_button.disabled = false
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
		next_challenge_phase.text = "Next Challenge: None"
		challenge_description.text = ""
		return

	var next_challenge := ChallengeManager.get_next_challenge_type()
	next_challenge_phase.text = "Next Challenge: Phase %s" % next_phase
	if next_challenge == -1:
		challenge_description.text = ""
	else:
		challenge_description.text = ChallengeManager.get_challenge_description(next_challenge)

	if ChallengeManager.active_challenge != -1:
		challenge_description.text = ChallengeManager.get_challenge_description(
			ChallengeManager.active_challenge
		)

func _update_turn_score() -> void:
	turn_score.text = "%s" % [GameManager.turn_score]

func _update_turn_multi() -> void:
	turn_multi.text = "%s" % [GameManager.turn_multi]

func _update_total_score() -> void:
	total_score.text = "%s" % [GameManager.total_score]

func _update_required_score() -> void:
	required_score.text = "%s" % [GameManager.required_score]

func _update_trigger_order_label() -> void:
	selected_trigger_order_label.text = TriggerOrderType.get_display_name(GameManager.trigger_order)

func _on_rune_activated(_rune: Rune) -> void:
	triggers_counter_label.text = "Triggers: %s" % [GameManager.get_runes_activated_this_turn()]
