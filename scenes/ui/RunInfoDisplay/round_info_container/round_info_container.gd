extends Control

@onready var round_label: Label = $VBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $VBoxContainer/TurnsContainer/TurnCounterLabel
@onready var required_score: Label = $VBoxContainer/RequiredScoreContainer/RequiredScore
@onready var score_this_round: Label = $VBoxContainer/ScoreContainer/ScoreThisRound
@onready var next_perk_counter: Label = $VBoxContainer/NextPerkCounter

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

var _required_counter: CountingNumber
var _round_score_counter: CountingNumber

func _ready() -> void:
	_required_counter = CountingNumber.for_label(self, required_score)
	_round_score_counter = CountingNumber.for_label(self, score_this_round)
	_required_counter.snap_to(GameManager.required_score)
	_round_score_counter.snap_to(GameManager.total_round_score)

	EventBus.turn_changed.connect(_update_turn_label)
	EventBus.total_round_score_changed.connect(_update_total_round_score)
	EventBus.required_score_changed.connect(_update_required_score)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.tile_card_activated.connect(_update_total_tile_card_activations)

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
	_round_score_counter.play(GameManager.total_round_score)

func _update_required_score() -> void:
	_required_counter.play(GameManager.required_score)

func _update_total_tile_card_activations(_rune: TileCard) -> void:
	next_perk_counter.text = "%s" % [GameManager.rune_activations_countdown()]


func _exit_tree() -> void:
	if _required_counter != null:
		_required_counter.kill()
	if _round_score_counter != null:
		_round_score_counter.kill()
