extends Node

## Tracks the run economy: spendable gold, per-turn or per-round gold earnings,
## and the free-reroll budget for card picks (the Merchant charges Gold for its rerolls).
## Gold is used for card activation and merchant purchases.


## Base starting Gold is Difficulty.BASE_STARTING_GOLD.
const ROUND_COMPLETION_GOLD := 3
## Extra gold per unused turn when finishing a round early.
const GOLD_PER_UNUSED_TURN := 3
## Gold at the end of each Day for each different Meal on the board (user, Nov 24: Meals no longer
## pay a Gold per serve). Untuned.
const GOLD_PER_UNIQUE_MEAL := 1
## Free card-pick rerolls per Day before the difficulty reduction (get_free_rerolls_per_day).
## Untuned. With one card pick a Day (at the end of it), 2 free rerolls show up to 9 cards.
const STARTING_REROLLS := 2
## Once the free rerolls are used, a card-pick reroll costs Gold: this much for the first paid one,
## then PAID_REROLL_STEP more for each paid reroll after it. The price never resets during a run.
const PAID_REROLL_BASE_COST := 1
const PAID_REROLL_STEP := 1

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
## Paid card-pick rerolls bought this run. Sets the next paid reroll's price.
var _paid_rerolls := 0


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
	var base_gold := Difficulty.BASE_STARTING_GOLD
	if GameManager.chef != null:
		base_gold = GameManager.chef.starting_gold(base_gold)
	_amount = maxi(0, base_gold - Difficulty.get_starting_gold_reduction(difficulty))
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
	_credit(amount_to_add)


func _credit(amount_to_add: int) -> void:
	_amount += amount_to_add
	_earned_this_turn += amount_to_add
	_total_earned_this_run += maxi(0, amount_to_add)
	GameManager.record_peak_gold_held(_amount)
	EventBus.gold_changed.emit(_amount)


func remove(amount_to_remove: int) -> void:
	_amount -= amount_to_remove
	_spent_this_round += amount_to_remove
	EventBus.gold_changed.emit(_amount)
	if amount_to_remove > 0:
		EventBus.gold_spent.emit(amount_to_remove)


## Gold taken by an event (Wages Due). Not spending: no gold_spent signal, so Techniques that
## react to spending don't trigger. Never goes below 0.
func lose(amount_to_lose: int) -> void:
	var lost := clampi(amount_to_lose, 0, _amount)
	if lost == 0:
		return
	_amount -= lost
	EventBus.gold_changed.emit(_amount)


func can_afford(cost: int) -> bool:
	return _amount >= cost


## Pays round completion gold and early-finish bonus when the goal is met.
func apply_round_speed_rewards(skipped_turns: int) -> void:
	var base_gold := ROUND_COMPLETION_GOLD
	var early_gold := GOLD_PER_UNUSED_TURN * skipped_turns
	var unique_meals := count_unique_board_meals()
	var meal_gold := GOLD_PER_UNIQUE_MEAL * unique_meals
	var total_gold := base_gold + early_gold + meal_gold

	if total_gold > 0:
		_credit(total_gold)
		AudioManager.play_sfx(UISounds.GOLD_GAINED)

	_last_speed_reward = {
		"skipped_turns": skipped_turns,
		"base_gold": base_gold,
		"early_gold": early_gold,
		"unique_meals": unique_meals,
		"meal_gold": meal_gold,
	}


## Different Meals (by card id) seated on the board right now.
func count_unique_board_meals() -> int:
	var map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if map == null:
		return 0
	var ids: Dictionary = {}
	for hex: Hex in map.get_all_hexes_with_runes():
		var card := hex.active_tile_card
		if card != null and card.type == TileCard.TileCardType.MEAL:
			ids[card.id] = true
	return ids.size()


## Called when a new turn begins so per-turn gold tracking resets.
func reset_turn_tracking() -> void:
	_earned_this_turn = 0


## Called when a new round begins so round-spend tracking resets.
func reset_round_tracking() -> void:
	_spent_this_round = 0


#region Rerolls

## Free rerolls each Day after the difficulty reduction.
func get_free_rerolls_per_day() -> int:
	return maxi(0, STARTING_REROLLS - Difficulty.get_free_reroll_reduction(GameManager.selected_difficulty))


## Refill the reroll pool. Runs at the start of every run and every day.
func reset_rerolls() -> void:
	_rerolls_remaining = get_free_rerolls_per_day()
	EventBus.rerolls_changed.emit(_rerolls_remaining)


## Gold the next card-pick reroll costs: 0 while free rerolls are left.
func get_reroll_cost() -> int:
	if _rerolls_remaining > 0:
		return 0
	return PAID_REROLL_BASE_COST + PAID_REROLL_STEP * _paid_rerolls


func can_reroll() -> bool:
	return _rerolls_remaining > 0 or can_afford(get_reroll_cost())


## Spend one reroll when a panel successfully refreshes its offer: a free one if any are left,
## otherwise pay its Gold price, which then goes up for the rest of the run.
func use_reroll() -> bool:
	if _rerolls_remaining > 0:
		_rerolls_remaining -= 1
		EventBus.rerolls_changed.emit(_rerolls_remaining)
		return true
	var cost := get_reroll_cost()
	if not can_afford(cost):
		return false
	remove(cost)
	_paid_rerolls += 1
	EventBus.rerolls_changed.emit(_rerolls_remaining)
	return true


## Paid rerolls only count toward the run's climbing price, so a new run starts at the base price.
func reset_paid_rerolls() -> void:
	_paid_rerolls = 0

#endregion


func capture_run_state() -> Dictionary:
	return {
		"total_earned_this_run": _total_earned_this_run,
		"amount": _amount,
		"earned_this_turn": _earned_this_turn,
		"spent_this_round": _spent_this_round,
		"rerolls_remaining": _rerolls_remaining,
		"paid_rerolls": _paid_rerolls,
	}


func apply_run_state(state: Dictionary) -> void:
	_amount = int(state.get("amount", 0))
	_total_earned_this_run = int(state.get("total_earned_this_run", 0))
	_earned_this_turn = int(state.get("earned_this_turn", 0))
	_spent_this_round = int(state.get("spent_this_round", 0))
	_last_speed_reward = {}
	_rerolls_remaining = maxi(0, int(state.get("rerolls_remaining", get_free_rerolls_per_day())))
	_paid_rerolls = maxi(0, int(state.get("paid_rerolls", 0)))
	EventBus.gold_changed.emit(_amount)
	EventBus.rerolls_changed.emit(_rerolls_remaining)
