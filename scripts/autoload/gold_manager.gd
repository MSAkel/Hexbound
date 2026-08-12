extends Node

# Tracks spendable gold and per-turn gold earnings.
# Gold is used for rune activation, merchant purchases, and rerolls.

var _amount: int = 0
# Resets at the start of each turn; used by runes that scale with gold earned during a turn.
var _earned_this_turn: int = 0


var amount: int:
	get:
		return _amount


var earned_this_turn: int:
	get:
		return _earned_this_turn


# Set starting gold for a new run based on difficulty and notify UI listeners.
func set_run_starting_gold(difficulty: Difficulty.Level) -> void:
	_amount = Difficulty.get_starting_gold(difficulty)
	_earned_this_turn = 0
	EventBus.gold_changed.emit(_amount)


func add(amount_to_add: int) -> void:
	_amount += amount_to_add
	_earned_this_turn += amount_to_add
	EventBus.gold_changed.emit(_amount)


func remove(amount_to_remove: int) -> void:
	_amount -= amount_to_remove
	EventBus.gold_changed.emit(_amount)


func can_afford(cost: int) -> bool:
	return _amount >= cost


# Called when a new turn begins so turn-scaling runes start from zero.
func reset_turn_tracking() -> void:
	_earned_this_turn = 0


func capture_run_state() -> Dictionary:
	return {
		"amount": _amount,
		"earned_this_turn": _earned_this_turn,
	}


func apply_run_state(state: Dictionary) -> void:
	_amount = int(state.get("amount", 0))
	_earned_this_turn = int(state.get("earned_this_turn", 0))
