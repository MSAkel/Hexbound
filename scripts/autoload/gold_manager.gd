extends Node

## Tracks spendable gold, merchant tokens, and per-turn or per-round gold earnings.
## Gold is used for rune activation, merchant purchases, and rerolls.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")

const MAX_MERCHANT_TOKENS := 5
const TILE_CARD_TOKEN_COST := 1
const ENHANCEMENT_TOKEN_COST := 2
## Flat gold paid every time a round goal is met.
const ROUND_COMPLETION_GOLD := 5
## Extra gold per unused turn when finishing a round early.
const GOLD_PER_UNUSED_TURN := 1

var _amount: int = 0
## Resets at the start of each turn. Used by runes that scale with gold earned during a turn.
var _earned_this_turn: int = 0
## Resets when a new round begins. Used by cards that scale with gold spent this round.
var _spent_this_round: int = 0
var _merchant_tokens: int = 0
## Breakdown from the most recent round-completion reward, for the summary UI.
var _last_speed_reward: Dictionary = {}


var amount: int:
	get:
		return _amount


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
	_earned_this_turn = 0
	_spent_this_round = 0
	_merchant_tokens = 0
	_last_speed_reward = {}
	EventBus.gold_changed.emit(_amount)
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)


func add(amount_to_add: int) -> void:
	_amount += amount_to_add
	_earned_this_turn += amount_to_add
	EventBus.gold_changed.emit(_amount)


## Gold from rune producers on the board. Thin alias over add for segment tracking callers.
func add_board_gold(amount_to_add: int) -> void:
	if amount_to_add == 0:
		return
	add(amount_to_add)


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


## Token price for a merchant item. Tile cards cost 1, enhancements cost 2.
func get_token_cost(card: Card) -> int:
	if card is Enhancement:
		return ENHANCEMENT_TOKEN_COST
	return TILE_CARD_TOKEN_COST


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
func apply_round_speed_rewards(skipped_turns: int, turns_remaining: int) -> void:
	var base_gold := ROUND_COMPLETION_GOLD
	var early_gold := GOLD_PER_UNUSED_TURN * skipped_turns
	var token_result := earn_merchant_tokens(skipped_turns)
	var total_gold := base_gold + early_gold

	if total_gold > 0:
		add(total_gold)
		AudioManager.play_sfx(UI_SOUNDS.GOLD_GAINED)

	_last_speed_reward = {
		"turns_remaining": turns_remaining,
		"skipped_turns": skipped_turns,
		"base_gold": base_gold,
		"early_gold": early_gold,
		"tokens_earned": token_result["earned"],
		"tokens_lost": token_result["lost"],
	}


## Called when a new turn begins so turn-scaling runes start from zero.
func reset_turn_tracking() -> void:
	_earned_this_turn = 0


## Called when a new round begins so round-scaling runes start from zero.
func reset_round_tracking() -> void:
	_spent_this_round = 0


func capture_run_state() -> Dictionary:
	return {
		"amount": _amount,
		"earned_this_turn": _earned_this_turn,
		"spent_this_round": _spent_this_round,
		"merchant_tokens": _merchant_tokens,
	}


func apply_run_state(state: Dictionary) -> void:
	_amount = int(state.get("amount", 0))
	_earned_this_turn = int(state.get("earned_this_turn", 0))
	_spent_this_round = int(state.get("spent_this_round", 0))
	_merchant_tokens = int(state.get("merchant_tokens", 0))
	_last_speed_reward = {}
	EventBus.gold_changed.emit(_amount)
	EventBus.merchant_tokens_changed.emit(_merchant_tokens)
