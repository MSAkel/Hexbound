extends Node

## Tracks the shared reroll budget for a run. Rune selection draws from this pool.

const MAX_REROLLS_PER_RUN := 3

var _remaining := MAX_REROLLS_PER_RUN


var remaining: int:
	get:
		return _remaining


## Refill the pool when a fresh run begins.
func reset_for_new_run() -> void:
	_remaining = MAX_REROLLS_PER_RUN
	EventBus.rerolls_changed.emit(_remaining)


func can_reroll() -> bool:
	return _remaining > 0


## Spend one reroll when a panel successfully refreshes its offer.
func use_reroll() -> bool:
	if not can_reroll():
		return false

	_remaining -= 1
	EventBus.rerolls_changed.emit(_remaining)
	return true


func capture_run_state() -> Dictionary:
	return {"remaining": _remaining}


func apply_run_state(state: Dictionary) -> void:
	_remaining = clampi(int(state.get("remaining", MAX_REROLLS_PER_RUN)), 0, MAX_REROLLS_PER_RUN)
	EventBus.rerolls_changed.emit(_remaining)
