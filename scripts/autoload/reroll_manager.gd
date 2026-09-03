extends Node

## Shared free-reroll budget for the 1-of-3 draft and the merchant stock refresh.

const STARTING_REROLLS_PER_RUN := 3

var _remaining := STARTING_REROLLS_PER_RUN


var remaining: int:
	get:
		return _remaining


## Refill the pool when a fresh run begins.
func reset_for_new_run() -> void:
	_remaining = STARTING_REROLLS_PER_RUN
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


## Condiment and other bonuses can push the pool above the starting amount.
func add_rerolls(amount: int) -> void:
	if amount <= 0:
		return
	_remaining += amount
	EventBus.rerolls_changed.emit(_remaining)


func capture_run_state() -> Dictionary:
	return {"remaining": _remaining}


func apply_run_state(state: Dictionary) -> void:
	_remaining = maxi(0, int(state.get("remaining", STARTING_REROLLS_PER_RUN)))
	EventBus.rerolls_changed.emit(_remaining)
