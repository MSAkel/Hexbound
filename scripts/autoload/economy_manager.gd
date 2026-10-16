extends Node

## Tracks the run economy: spendable gold, per-turn or per-round gold earnings,
## and the free-reroll budget shared by the 1-of-3 draft and the merchant stock refresh.
## Gold is used for card activation and merchant purchases.


## Starting gold amount is set in diffculty.gd
const ROUND_COMPLETION_GOLD := 3
## Extra gold per unused turn when finishing a round early.
const GOLD_PER_UNUSED_TURN := 1
const STARTING_REROLLS := 3

var _amount: int = 0
## Gross gold gained during the run. Starting gold and spending do not affect this total.
var _total_earned_this_run: int = 0
## Resets at the start of each turn. Shown on the round-complete summary.
var _earned_this_turn: int = 0
## Resets when a new round begins. Used by cards that scale with gold spent this round.
var _spent_this_round: int = 0
## Breakdown from the most recent round-completion reward, for the summary UI.
var _last_speed_reward: Dictionary = {}
var _rerolls_remaining: int = STARTING_REROLLS


var amount: int:
	get:
		return _amount


var total_earned_this_run: int:
	get:
		return _total_earned_this_run


var earned_this_turn: int:
	get:
		return _earned_this_turn


var spent_this_round: int:
	get:
		return _spent_this_round


var last_speed_reward: Dictionary:
	get:
		return _last_speed_reward


var rerolls_remaining: int:
	get:
		return _rerolls_remaining


## Set starting gold for a new run based on difficulty and notify UI listeners.
func set_run_starting_gold(difficulty: Difficulty.Level) -> void:
	_amount = Difficulty.get_starting_gold(difficulty)
	if GameManager.chef_speciality != null:
		_amount += int(GameManager.chef_speciality.extra_starting_gold())
	_total_earned_this_run = 0
	_earned_this_turn = 0
	_spent_this_round = 0
	_last_speed_reward = {}
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)


## Debug helper. Replaces the current gold wallet without counting it as earned or spent.
func set_amount(new_amount: int) -> void:
	_amount = maxi(0, new_amount)
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)


func add(amount_to_add: int) -> void:
	# Austerity blocks every gold gain, including round-clear payouts still on that round.
	if amount_to_add > 0 and not EventManager.can_gain_gold():
		return
	_amount += amount_to_add
	_earned_this_turn += amount_to_add
	_total_earned_this_run += maxi(0, amount_to_add)
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)


func remove(amount_to_remove: int) -> void:
	_amount -= amount_to_remove
	_spent_this_round += amount_to_remove
	EventBus.gold_changed.emit(_amount)


func can_afford(cost: int) -> bool:
	return _amount >= cost


## Pays round completion gold and early-finish bonus when the goal is met.
func apply_round_speed_rewards(skipped_turns: int) -> void:
	var gourmet_bonus := 0
	if GameManager.chef_speciality != null:
		gourmet_bonus = int(GameManager.chef_speciality.extra_day_completion_gold())
	var base_gold := ROUND_COMPLETION_GOLD + gourmet_bonus
	var early_gold := GOLD_PER_UNUSED_TURN * skipped_turns
	var total_gold := base_gold + early_gold
	if not EventManager.can_gain_gold():
		base_gold = 0
		early_gold = 0
		total_gold = 0

	if total_gold > 0:
		add(total_gold)
		AudioManager.play_sfx(UISounds.GOLD_GAINED)

	_last_speed_reward = {
		"skipped_turns": skipped_turns,
		"base_gold": base_gold,
		"early_gold": early_gold,
	}


## Called when a new turn begins so per-turn gold tracking resets.
func reset_turn_tracking() -> void:
	_earned_this_turn = 0


## Called when a new round begins so round-spend tracking resets.
func reset_round_tracking() -> void:
	_spent_this_round = 0


#region Rerolls

## Refill the reroll pool. Runs at the start of every run and every day.
func reset_rerolls() -> void:
	_rerolls_remaining = STARTING_REROLLS
	EventBus.rerolls_changed.emit(_rerolls_remaining)


func can_reroll() -> bool:
	return _rerolls_remaining > 0


## Spend one reroll when a panel successfully refreshes its offer.
func use_reroll() -> bool:
	if not can_reroll():
		return false

	_rerolls_remaining -= 1
	EventBus.rerolls_changed.emit(_rerolls_remaining)
	return true


## Condiment and other bonuses can push the pool above the starting amount.
func add_rerolls(amount_to_add: int) -> void:
	if amount_to_add <= 0:
		return
	_rerolls_remaining += amount_to_add
	EventBus.rerolls_changed.emit(_rerolls_remaining)

#endregion


func capture_run_state() -> Dictionary:
	return {
		"total_earned_this_run": _total_earned_this_run,
		"amount": _amount,
		"earned_this_turn": _earned_this_turn,
		"spent_this_round": _spent_this_round,
		"rerolls_remaining": _rerolls_remaining,
	}


func apply_run_state(state: Dictionary) -> void:
	_amount = int(state.get("amount", 0))
	_total_earned_this_run = int(state.get("total_earned_this_run", 0))
	_earned_this_turn = int(state.get("earned_this_turn", 0))
	_spent_this_round = int(state.get("spent_this_round", 0))
	_last_speed_reward = {}
	_rerolls_remaining = maxi(0, int(state.get("rerolls_remaining", STARTING_REROLLS)))
	EventBus.gold_changed.emit(_amount)
	EventBus.rerolls_changed.emit(_rerolls_remaining)
