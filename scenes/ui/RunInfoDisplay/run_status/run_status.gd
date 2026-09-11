extends PanelContainer

## Top run HUD for round, remaining turns, gold, and merchant tokens.

@onready var round_label: Label = $HBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $HBoxContainer/TurnsContainer/TurnCounterLabel
@onready var turns_container: Control = $HBoxContainer/TurnsContainer
@onready var gold_row: Control = $HBoxContainer/GoldRow
@onready var gold_amount_label: Label = $HBoxContainer/GoldRow/GoldAmountLabel
@onready var token_row: Control = $HBoxContainer/TokenRow
@onready var token_amount_label: Label = $HBoxContainer/TokenRow/TokenAmountLabel
@onready var reroll_button: Button = $HBoxContainer/RerollButton

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18

const TOOLTIP_DAY := "Current day. Nine days complete a run."
const TOOLTIP_HOURS := "Hours left before kitchen close. Reach the day target with hours to spare."
const TOOLTIP_GOLD := "Gold. Spend at the merchant on cards and condiments."
const TOOLTIP_TOKENS := "Merchant tokens. Pay for shop items instead of gold. Max %d." % GoldManager.MAX_MERCHANT_TOKENS

var _gold_counter: CountingNumber
var _round_counter: CountingNumber
var _turn_counter: CountingNumber
var _punch_tweens: Dictionary = {}


func _ready() -> void:
	if reroll_button != null:
		reroll_button.pressed.connect(_on_reroll_button_pressed)
		# turn_started fires before finish_turn_processing clears is_processing_turn.
		EventBus.turn_started.connect(_queue_reroll_button_refresh)
		EventBus.turn_ended.connect(_update_reroll_button)
		EventBus.card_played.connect(_update_reroll_button)
		EventBus.rerolls_changed.connect(_update_reroll_button)
		_update_reroll_button()

	_gold_counter = CountingNumber.for_label(self, gold_amount_label)
	_round_counter = CountingNumber.new(
		self,
		func(text: String) -> void: round_label.text = FeastDisplay.day_label(int(text))
	)
	_turn_counter = CountingNumber.for_label(self, turn_counter_label)

	_gold_counter.snap_to(GoldManager.amount)
	_update_token_label(GoldManager.merchant_tokens)
	_round_counter.snap_to(GameManager.current_round)
	_turn_counter.snap_to(GameManager.remaining_turns)

	EventBus.gold_changed.connect(_on_gold_changed)
	EventBus.merchant_tokens_changed.connect(_on_merchant_tokens_changed)
	EventBus.round_changed.connect(_on_round_changed)
	EventBus.turn_changed.connect(_on_turn_changed)
	_bind_status_tooltips()


func _bind_status_tooltips() -> void:
	for control: Control in [round_label, turns_container, gold_row, token_row]:
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_tooltip(round_label, TOOLTIP_DAY)
	_bind_tooltip(turns_container, TOOLTIP_HOURS)
	_bind_tooltip(gold_row, TOOLTIP_GOLD)
	_bind_tooltip(token_row, TOOLTIP_TOKENS)


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


func _on_merchant_tokens_changed(new_amount: int) -> void:
	_update_token_label(new_amount)
	_punch(token_amount_label)


func _update_token_label(amount: int) -> void:
	token_amount_label.text = str(amount)


func _on_round_changed(new_round: int) -> void:
	_play_counter(_round_counter, new_round, round_label)


func _on_turn_changed() -> void:
	_play_counter(_turn_counter, GameManager.remaining_turns, turn_counter_label)


func _on_reroll_button_pressed() -> void:
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	if hand == null:
		return
	if EventManager.reroll_fail_hour_pack(hand):
		RunSaveManager.request_autosave()
	_update_reroll_button()


func _queue_reroll_button_refresh(_unused = null) -> void:
	call_deferred("_update_reroll_button")


func _update_reroll_button(_unused = null) -> void:
	if reroll_button == null:
		return
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	var can_reroll := EventManager.can_reroll_fail_hour_pack(hand)
	# Stay visible while the run still has rerolls. Disable when the deal cannot be refreshed.
	reroll_button.visible = RerollManager.remaining > 0 and not RoundFlow.is_transitioning()
	reroll_button.disabled = not can_reroll
	var remaining := RerollManager.remaining
	if remaining <= 0:
		reroll_button.text = "0 rerolls"
	else:
		reroll_button.text = "Reroll (%d)" % remaining


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
