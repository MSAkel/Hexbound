extends Node

## Tracks spendable gold, merchant tokens, and per-turn or per-round gold earnings.
## Gold is used for rune activation, merchant purchases, and rerolls.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

const MAX_MERCHANT_TOKENS := 5
const MERCHANT_TOKEN_COST := 1
## Flat gold paid every time a round goal is met.
const ROUND_COMPLETION_GOLD := 5
## Extra gold per unused turn when finishing a round early.
const GOLD_PER_UNUSED_TURN := 1

var _amount: int = 0
## Gross gold gained during the run. Starting gold and spending do not affect this total.
var _total_earned_this_run: int = 0
## Resets at the start of each turn. Shown on the round-complete summary.
var _earned_this_turn: int = 0
## Resets when a new round begins. Used by cards that scale with gold spent this round.
var _spent_this_round: int = 0
var _merchant_tokens: int = 0
## Breakdown from the most recent round-completion reward, for the summary UI.
var _last_speed_reward: Dictionary = {}


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


var merchant_tokens: int:
	get:
		return _merchant_tokens


var last_speed_reward: Dictionary:
	get:
		return _last_speed_reward


## Set starting gold for a new run based on difficulty and notify UI listeners.
func set_run_starting_gold(difficulty: Difficulty.Level) -> void:
	_amount = Difficulty.get_starting_gold(difficulty)
	_total_earned_this_run = 0
	_earned_this_turn = 0
	_spent_this_round = 0
	_merchant_tokens = 0
	_last_speed_reward = {}
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)


## Debug helper. Replaces the current gold wallet without counting it as earned or spent.
func set_amount(new_amount: int) -> void:
	_amount = maxi(0, new_amount)
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)


## Debug helper. Sets merchant tokens without exceeding the wallet cap.
func set_merchant_tokens(new_amount: int) -> void:
	_merchant_tokens = clampi(new_amount, 0, MAX_MERCHANT_TOKENS)
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)


func add(amount_to_add: int) -> void:
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


func can_afford_tokens(cost: int) -> bool:
	return cost > 0 and _merchant_tokens >= cost


func spend_tokens(cost: int) -> bool:
	if not can_afford_tokens(cost):
		return false
	_merchant_tokens -= cost
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)
	return true


## Awards tokens up to the wallet cap. Returns how many were earned and how many were lost to overflow.
func earn_merchant_tokens(amount_to_earn: int) -> Dictionary:
	if amount_to_earn <= 0:
		return {"earned": 0, "lost": 0}

	var space := MAX_MERCHANT_TOKENS - _merchant_tokens
	var earned := mini(amount_to_earn, space)
	var lost := amount_to_earn - earned
	_merchant_tokens += earned
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)
	return {"earned": earned, "lost": lost}


## Pays round completion gold, early-finish bonus, and merchant tokens when the goal is met.
func apply_round_speed_rewards(skipped_turns: int) -> void:
	var base_gold := ROUND_COMPLETION_GOLD
	var early_gold := GOLD_PER_UNUSED_TURN * skipped_turns
	var token_result := earn_merchant_tokens(skipped_turns)
	var total_gold := base_gold + early_gold

	if total_gold > 0:
		add(total_gold)
		AudioManager.play_sfx(UI_SOUNDS.GOLD_GAINED)

	_last_speed_reward = {
		"skipped_turns": skipped_turns,
		"base_gold": base_gold,
		"early_gold": early_gold,
		"tokens_earned": token_result["earned"],
		"tokens_lost": token_result["lost"],
	}


## Called when a new turn begins so per-turn gold tracking resets.
func reset_turn_tracking() -> void:
	_earned_this_turn = 0


## Called when a new round begins so round-spend tracking resets.
func reset_round_tracking() -> void:
	_spent_this_round = 0


func capture_run_state() -> Dictionary:
	return {
		"total_earned_this_run": _total_earned_this_run,
		"amount": _amount,
		"earned_this_turn": _earned_this_turn,
		"spent_this_round": _spent_this_round,
		"merchant_tokens": _merchant_tokens,
	}


func apply_run_state(state: Dictionary) -> void:
	_amount = int(state.get("amount", 0))
	_total_earned_this_run = int(state.get("total_earned_this_run", 0))
	_earned_this_turn = int(state.get("earned_this_turn", 0))
	_spent_this_round = int(state.get("spent_this_round", 0))
	_merchant_tokens = int(state.get("merchant_tokens", 0))
	_last_speed_reward = {}
	EventBus.gold_changed.emit(_amount)
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)
