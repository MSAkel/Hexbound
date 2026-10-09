extends PanelContainer

## Top run HUD for round, remaining turns, and gold.

@onready var round_label: Label = $HBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $HBoxContainer/TurnsContainer/TurnCounterLabel
@onready var turns_container: Control = $HBoxContainer/TurnsContainer
@onready var gold_row: Control = $HBoxContainer/GoldRow
@onready var gold_amount_label: Label = $HBoxContainer/GoldRow/GoldAmountLabel

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18

const TOOLTIP_DAY := "Current day. Nine days complete a run."
const TOOLTIP_HOURS := "Hours left before kitchen close. Reach the day target with hours to spare."
const TOOLTIP_GOLD := "Gold. Spend at the merchant on cards and condiments."

var _gold_counter: CountingNumber
var _round_counter: CountingNumber
var _turn_counter: CountingNumber
var _punch_tweens: Dictionary = {}


func _ready() -> void:
	_gold_counter = CountingNumber.for_label(self, gold_amount_label)
	_round_counter = CountingNumber.new(
		self,
		func(text: String) -> void: round_label.text = FeastDisplay.day_label(int(text))
	)
	_turn_counter = CountingNumber.for_label(self, turn_counter_label)

	_gold_counter.snap_to(GoldManager.amount)
	_round_counter.snap_to(GameManager.current_round)
	_turn_counter.snap_to(GameManager.remaining_turns)

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.turn_changed.connect(_on_turn_changed)
	_bind_status_tooltips()


func _bind_status_tooltips() -> void:
	for control: Control in [round_label, turns_container, gold_row]:
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_tooltip(round_label, TOOLTIP_DAY)
	_bind_tooltip(turns_container, TOOLTIP_HOURS)
	_bind_tooltip(gold_row, TOOLTIP_GOLD)


func _bind_tooltip(control: Control, text: String) -> void:
	if control == null:
		return
	control.mouse_entered.connect(_show_status_tooltip.bind(control, text))
	control.mouse_exited.connect(_hide_status_tooltip)


func _show_status_tooltip(control: Control, text: String) -> void:
	EventBus.toggle_tooltip.emit(true, text, control.get_global_rect())


func _hide_status_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_gold_changed(new_amount: int) -> void:
	_play_counter(_gold_counter, new_amount, gold_amount_label)


func _on_round_changed(new_round: int) -> void:
	_play_counter(_round_counter, new_round, round_label)


func _on_turn_changed() -> void:
	_play_counter(_turn_counter, GameManager.remaining_turns, turn_counter_label)


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
