extends PanelContainer

## Top run HUD for the Day and Hours left. Gold lives on the gold panel under the chef portrait.

@onready var round_label: Label = $HBoxContainer/RoundLabel
@onready var turn_counter_label: Label = $HBoxContainer/TurnsContainer/TurnCounterLabel
@onready var turns_container: Control = $HBoxContainer/TurnsContainer
@onready var _merge_sparks: CPUParticles2D = %MergeSparks

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18
# The day intro lands harder than a plain counter tick.
const DAY_MERGE_PUNCH_SCALE := 1.4
const DAY_MERGE_FLASH := Color(1.6, 1.45, 1.1, 1.0)
const DAY_MERGE_FLASH_DURATION := 0.4

const TOOLTIP_DAY := "Current day. %d days complete a run." % ScoreProgression.RUN_LENGTH_ROUNDS
const TOOLTIP_HOURS := "Hours left before kitchen close. Reach the day target with hours to spare."

var _round_counter: CountingNumber
var _turn_counter: CountingNumber
var _punch_tweens: Dictionary = {}
var _flash_tween: Tween


func _ready() -> void:
	_round_counter = CountingNumber.new(
		self,
		func(text: String) -> void: round_label.text = GameTerms.day_label(int(text))
	)
	_turn_counter = CountingNumber.for_label(self, turn_counter_label)

	_snap_all()

	EventBus.round_changed.connect(_on_round_changed)
	EventBus.day_intro_landed.connect(_on_day_intro_landed)
	EventBus.turn_changed.connect(_on_turn_changed)
	EventBus.run_state_loaded.connect(_snap_all)
	_bind_status_tooltips()


## This node readies before the run resets, so the first values can be last run's.
func _snap_all() -> void:
	for control: Control in _punch_tweens:
		(_punch_tweens[control] as Tween).kill()
		control.scale = Vector2.ONE
	_punch_tweens.clear()
	# A save mid-transition has already advanced the round. The intro still owes the reveal.
	_round_counter.snap_to(GameManager.current_round - (1 if RoundFlow.is_day_reveal_pending() else 0))
	_turn_counter.snap_to(GameManager.remaining_turns)


func _bind_status_tooltips() -> void:
	for control: Control in [round_label, turns_container]:
		if control == null:
			continue
		control.mouse_filter = Control.MOUSE_FILTER_STOP
	_bind_tooltip(round_label, TOOLTIP_DAY)
	_bind_tooltip(turns_container, TOOLTIP_HOURS)


func _bind_tooltip(control: Control, text: String) -> void:
	if control == null:
		return
	control.mouse_entered.connect(_show_status_tooltip.bind(control, text))
	control.mouse_exited.connect(_hide_status_tooltip)


func _show_status_tooltip(control: Control, text: String) -> void:
	EventBus.toggle_tooltip.emit(true, text, control.get_global_rect())


func _hide_status_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


func _on_round_changed(new_round: int) -> void:
	# The round advances at the summary. The new day shows when the day intro lands.
	if RoundFlow.is_transitioning():
		return
	_play_counter(_round_counter, new_round, round_label)


func _on_day_intro_landed(day: int) -> void:
	_round_counter.snap_to(day)
	if GameManager.skip_presentation:
		return
	_punch(round_label, DAY_MERGE_PUNCH_SCALE)
	ScoreLandFx.play_panel_pulse(self, self)
	_merge_sparks.global_position = round_label.get_global_rect().get_center()
	_merge_sparks.restart()
	AudioManager.play_sfx(UISounds.MERCHANT_BELL)
	if _flash_tween != null and _flash_tween.is_valid():
		_flash_tween.kill()
	modulate = DAY_MERGE_FLASH
	_flash_tween = create_tween()
	_flash_tween.tween_property(self, "modulate", Color.WHITE, DAY_MERGE_FLASH_DURATION / GameManager.game_speed)


func _on_turn_changed() -> void:
	_play_counter(_turn_counter, GameManager.remaining_turns, turn_counter_label)


func _play_counter(counter: CountingNumber, target: int, punch_target: Control) -> void:
	var tween := counter.play(target)
	if tween != null:
		_punch(punch_target)


func _punch(control: Control, punch_scale: float = PUNCH_SCALE) -> void:
	if control == null:
		return

	var existing: Variant = _punch_tweens.get(control)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE

	var duration := PUNCH_DURATION / GameManager.game_speed
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(punch_scale, punch_scale), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tweens[control] = tween


func _exit_tree() -> void:
	if _round_counter != null:
		_round_counter.kill()
	if _turn_counter != null:
		_turn_counter.kill()
