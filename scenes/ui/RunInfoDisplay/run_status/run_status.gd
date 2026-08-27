extends PanelContainer

## Combined run HUD for round, remaining turns, gold, and score vs the round target.

@onready var round_label: Label = $VBoxContainer/HBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $VBoxContainer/HBoxContainer/TurnsContainer/TurnCounterLabel
@onready var gold_amount_label: Label = $VBoxContainer/HBoxContainer/GoldRow/GoldAmountLabel
@onready var token_amount_label: Label = $VBoxContainer/HBoxContainer/TokenRow/TokenAmountLabel
@onready var score_this_round: Label = $VBoxContainer/ScoreContainer/HBoxContainer/ScoreThisRound
@onready var required_score: Label = $VBoxContainer/ScoreContainer/HBoxContainer/RequiredScore
@onready var progress_bar: ProgressBar = $VBoxContainer/ProgressBar

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18

var _gold_counter: CountingNumber
var _round_counter: CountingNumber
var _turn_counter: CountingNumber
var _required_counter: CountingNumber
var _round_score_counter: CountingNumber
var _punch_tweens: Dictionary = {}
## Segment products already flown into this HUD during the current turn resolve.
var _preview_turn_score: int = 0


func _ready() -> void:
	_gold_counter = CountingNumber.for_label(self, gold_amount_label)
	_round_counter = CountingNumber.new(
		self,
		func(text: String) -> void: round_label.text = "Round %s" % text
	)
	_turn_counter = CountingNumber.for_label(self, turn_counter_label)
	_required_counter = CountingNumber.for_label(self, required_score, false, _on_required_counted)
	_round_score_counter = CountingNumber.for_label(self, score_this_round, false, _on_score_counted)

	_gold_counter.snap_to(GoldManager.amount)
	_update_token_label(GoldManager.merchant_tokens)
	_round_counter.snap_to(GameManager.current_round)
	_turn_counter.snap_to(GameManager.remaining_turns)
	_required_counter.snap_to(GameManager.required_score)
	_round_score_counter.snap_to(GameManager.total_round_score)

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.merchant_tokens_changed.connect(_on_merchant_tokens_changed)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.turn_changed.connect(_on_turn_changed)
	EventBus.total_round_score_changed.connect(_on_total_round_score_changed)
	EventBus.required_score_changed.connect(_on_required_score_changed)
	EventBus.segment_score_revealed.connect(_on_segment_score_revealed)
	EventBus.turn_ended.connect(_on_turn_ended)


func _on_gold_changed(new_amount: int) -> void:
	_play_counter(_gold_counter, new_amount, gold_amount_label)


func _on_merchant_tokens_changed(new_amount: int) -> void:
	_update_token_label(new_amount)
	_punch(token_amount_label)


func _update_token_label(amount: int) -> void:
	token_amount_label.text = str(amount)


func _on_round_changed(new_round: int) -> void:
	_play_counter(_round_counter, new_round, round_label)


func _on_turn_changed() -> void:
	_play_counter(_turn_counter, GameManager.remaining_turns, turn_counter_label)


func _on_turn_ended() -> void:
	_preview_turn_score = 0


func _on_total_round_score_changed() -> void:
	_preview_turn_score = 0
	_play_counter(_round_score_counter, GameManager.total_round_score, score_this_round)


## Each flying segment product adds to the HUD as it lands, before the turn score is committed.
func _on_segment_score_revealed(_segment_index: int, total_score: int) -> void:
	_preview_turn_score += total_score
	_play_counter(
		_round_score_counter,
		GameManager.total_round_score + _preview_turn_score,
		score_this_round
	)


func _on_required_score_changed() -> void:
	_play_counter(_required_counter, GameManager.required_score, required_score)


## Keeps the bar fill in lockstep with the counting score readout.
func _on_score_counted(as_int: int) -> void:
	progress_bar.value = as_int


## Required score is the bar maximum. Guard against a zero max which collapses the fill.
func _on_required_counted(as_int: int) -> void:
	progress_bar.max_value = max(as_int, 1)


func _play_counter(counter: CountingNumber, target: int, punch_target: Control) -> void:
	var tween := counter.play(target)
	if tween != null:
		_punch(punch_target)


func _punch(control: Control) -> void:
	if control == null:
		return

	var existing: Variant = _punch_tweens.get(control)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE

	var duration := PUNCH_DURATION / GameManager.game_speed
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tweens[control] = tween


func _exit_tree() -> void:
	if _gold_counter != null:
		_gold_counter.kill()
	if _round_counter != null:
		_round_counter.kill()
	if _turn_counter != null:
		_turn_counter.kill()
	if _required_counter != null:
		_required_counter.kill()
	if _round_score_counter != null:
		_round_score_counter.kill()
