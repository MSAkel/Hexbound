extends Node

## Owns the ordered round-transition sequence so no single screen decides what comes next.
## Round goal met -> summary -> rune pick -> merchant -> event reveal -> first turn of the round.
## Mid-turn rune picks also use rune_selection_ui outside this transition.

enum Step {
	## Normal play. No transition is running.
	IDLE,
	SUMMARY,
	RUNE_PICK,
	MERCHANT,
	EVENT_REVEAL,
	VICTORY,
}

## Force-completes the reveal step when the banner never reports back, so a missing or
## freed banner node cannot strand the run mid-transition. The overlay waits for a click,
## so this is only a failsafe, not a read timer.
const EVENT_REVEAL_TIMEOUT := 120.0

var _step: Step = Step.IDLE
## Armed when a round advance lands on an event round. RoundFlow owns this, not EventManager.
var _event_reveal_armed := false
## The victory branch advances the round after the merchant instead of at the summary.
var _advance_round_after_merchant := false
## Event that governed the round being left. The reward rune pick still belongs to that
## round, so an event starting on the next round must not change it.
var _outgoing_event := -1
## Round that owns a transition rune pick. Set when entering RUNE_PICK.
var _transition_rune_pick_round := 1
## Identity check so a stale timeout cannot complete a newer reveal.
var _reveal_timeout_token: SceneTreeTimer = null


func _ready() -> void:
	EventBus.merchant_closed.connect(_on_merchant_closed)
	EventBus.event_reveal_finished.connect(_on_event_reveal_finished)


func is_transitioning() -> bool:
	return _step != Step.IDLE


## True while an event reveal is queued but has not played yet.
func has_armed_event_reveal() -> bool:
	return _event_reveal_armed


## Event of the round that just finished, or -1 when it had none.
## Only meaningful while a transition is running.
func get_outgoing_event() -> int:
	return _outgoing_event


func is_transition_rune_pick() -> bool:
	return _step == Step.RUNE_PICK


func get_transition_rune_pick_round() -> int:
	return _transition_rune_pick_round


## True when the merchant step will advance the round after closing, as on the victory path.
func will_advance_round_after_merchant() -> bool:
	return _advance_round_after_merchant


func get_step() -> Step:
	return _step


#region Entry points

## Starts the transition for a completed round that still has rounds left to play.
func begin_round_transition() -> void:
	_advance_round_after_merchant = false
	_outgoing_event = EventManager.active_event
	_enter_step(Step.SUMMARY)


## Starts the transition for the run's final event round.
## The rune pick and merchant run before the next round begins.
func begin_victory_transition() -> void:
	_advance_round_after_merchant = true
	_outgoing_event = EventManager.active_event
	_enter_step(Step.VICTORY)

#endregion

#region Step completion callbacks

func notify_summary_confirmed() -> void:
	if _step != Step.SUMMARY:
		return

	# The round bonus has to land before the merchant so the player can spend it there.
	GameManager.advance_round()
	_arm_event_reveal()
	_enter_step(Step.RUNE_PICK)


func notify_victory_continue() -> void:
	if _step != Step.VICTORY:
		return

	_enter_step(Step.RUNE_PICK)


func notify_rune_picked() -> void:
	# Turn-loop rune picks happen outside a transition and must not drive the flow.
	if _step != Step.RUNE_PICK:
		return

	_enter_step(Step.MERCHANT)


func _on_merchant_closed() -> void:
	if _step != Step.MERCHANT:
		return

	if _advance_round_after_merchant:
		_advance_round_after_merchant = false
		GameManager.advance_round()
		_arm_event_reveal()

	if _event_reveal_armed:
		_event_reveal_armed = false
		# Reveal before the turn starts so the banner leads into the effects it describes.
		if EventManager.play_reveal():
			_enter_step(Step.EVENT_REVEAL)
			return

	_finish_transition()


func _on_event_reveal_finished() -> void:
	if _step != Step.EVENT_REVEAL:
		return

	_finish_transition()

#endregion

#region Step machine

func _enter_step(step: Step) -> void:
	_step = step

	match step:
		Step.SUMMARY:
			UiManager.show_round_complete_panel.emit()
		Step.VICTORY:
			EventBus.event_banner_hidden.emit()
			EventBus.all_events_completed.emit()
		Step.RUNE_PICK:
			# Summary already advanced the round. Victory keeps the completed round number.
			if _advance_round_after_merchant:
				_transition_rune_pick_round = GameManager.current_round
			else:
				_transition_rune_pick_round = maxi(1, GameManager.current_round - 1)
			if EventManager.should_auto_grant_rune(true):
				EventManager.grant_auto_rune(true)
				notify_rune_picked()
			else:
				UiManager.show_runes_choice_panel.emit()
		Step.MERCHANT:
			UiManager.show_merchant_panel.emit()
		Step.EVENT_REVEAL:
			_start_reveal_timeout()

	RunSaveManager.request_autosave()


## The single place a transition ends and play resumes.
func _finish_transition() -> void:
	_reveal_timeout_token = null
	_step = Step.IDLE
	_event_reveal_armed = false
	_advance_round_after_merchant = false
	_outgoing_event = -1

	EventBus.turn_started.emit()
	RunSaveManager.request_autosave()


func _arm_event_reveal() -> void:
	_event_reveal_armed = EventManager.active_event != -1


func _start_reveal_timeout() -> void:
	var timer := get_tree().create_timer(EVENT_REVEAL_TIMEOUT)
	_reveal_timeout_token = timer
	await timer.timeout

	if _reveal_timeout_token == timer and _step == Step.EVENT_REVEAL:
		push_warning("RoundFlow: event reveal never reported back, continuing the round.")
		_finish_transition()

#endregion

#region Run save / load

func reset_for_new_run() -> void:
	_abort_transition()


## Drops any in-flight round transition so sandbox tools can teleport the run.
func debug_abort_transition() -> void:
	_abort_transition()


func _abort_transition() -> void:
	_reveal_timeout_token = null
	_step = Step.IDLE
	_event_reveal_armed = false
	_advance_round_after_merchant = false
	_outgoing_event = -1
	_transition_rune_pick_round = 1


func capture_run_state() -> Dictionary:
	return {
		"step": _step,
		"event_reveal_armed": _event_reveal_armed,
		"advance_round_after_merchant": _advance_round_after_merchant,
		"outgoing_event": _outgoing_event,
		"transition_rune_pick_round": _transition_rune_pick_round,
	}


func apply_run_state(state: Dictionary) -> void:
	_reveal_timeout_token = null
	_step = int(state.get("step", Step.IDLE)) as Step
	_event_reveal_armed = bool(state.get("event_reveal_armed", false))
	_advance_round_after_merchant = bool(state.get("advance_round_after_merchant", false))
	_outgoing_event = int(state.get("outgoing_event", -1))
	_transition_rune_pick_round = int(state.get("transition_rune_pick_round", GameManager.current_round))


## Re-shows the panel the saved run was sitting on so a mid-transition save resumes in place.
func restore_after_load() -> void:
	if _step == Step.IDLE:
		return

	# A reveal cannot resume mid-animation. The event is already active and its banner
	# was restored docked, so the only thing left owed is the round's first turn.
	if _step == Step.EVENT_REVEAL:
		_finish_transition()
		return

	_enter_step(_step)

#endregion
