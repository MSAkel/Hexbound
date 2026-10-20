extends "res://scripts/debug/playtest/playtest_policy.gd"

## Plays like a careful player who previews each option before committing.
## Every play, pick, buy, staff move and drink is tried as a what-if Hour with the real resolver
## (PlaytestSim). Card text, staff, station perks and the chef speciality all count because the game
## runs them, so there is no card table to keep in sync with balance changes.
##
## Values are in run-score units: the change in one Hour's score times the Hours left in the run.
## Gold converts through what a merchant card is worth right now, so it fades as the run ends.

## Steers drafting toward each speciality's future payoff. The simulation already applies the
## speciality itself, so these only cover what one Hour cannot show.
const CHEF_PROFILES := {
	"sous_chef": {
		## Every third Kitchenware trigger repeats, so each extra Kitchenware raises later repeats.
		"kitchenware_pick_bias": 1.25,
		"beverage_pick_bias": 1.0,
		"gold_weight": 1.0,
		"shop_reserve": 4,
	},
	"sommelier": {
		"kitchenware_pick_bias": 1.0,
		## Beverages pay double, so draft them before their recipe is on the board.
		"beverage_pick_bias": 1.6,
		"gold_weight": 1.0,
		"shop_reserve": 4,
	},
	"gourmet_restaurant": {
		"kitchenware_pick_bias": 1.0,
		"beverage_pick_bias": 1.0,
		## Extra gold every day makes each coin worth less, so spend more freely.
		"gold_weight": 0.7,
		"shop_reserve": 0,
	},
}
const DEFAULT_PROFILE := {
	"kitchenware_pick_bias": 1.0,
	"beverage_pick_bias": 1.0,
	"gold_weight": 1.0,
	"shop_reserve": 4,
}

## Reroll an offer whose best card is worth less than this share of a typical pick.
const REROLL_BELOW_MARKET := 0.55
## How quickly the typical-pick estimate follows new offers.
const MARKET_SMOOTHING := 0.3
## Candidate spots per station. The first and last empty spot cover order-sensitive effects.
const MAX_HEXES_PER_STATION := 2
## Weakest seated cards tried as replacement targets once a card has no empty spot left.
const MAX_REPLACE_CANDIDATES := 3
## A Meal waiting on its recipe is worth this share of a typical pick, less per missing card.
const MEAL_POTENTIAL_SHARE := 0.8
## Moving a base station one card closer to a type is worth this share of a typical pick.
const STATION_PROGRESS_SHARE := 0.15
## A spot on a full board costs up to this share of a typical pick.
const SLOT_COST_SHARE := 0.25
## Cards tried as a target for a one-shot drink.
const DRINK_TARGETS := 5
## Cards considered for Swap Spots, all pairs among them.
const SWAP_CANDIDATES := 6
## Merchant rerolls per visit while gold is tight. Spare gold buys more looks at the shelf,
## which is also how the bot finds copies of its board cards to merge.
const MIN_MERCHANT_REROLLS := 3
const MAX_MERCHANT_REROLLS := 12
const GOLD_VALUE_SHARE := 0.5
## Gold up to about two visits of buying. Past this, each coin is worth less.
const GOLD_COMFORT := 12
## Buy a shelf item worth at least this share of a typical pick per merchant card price.
const BUY_FLOOR_SHARE := 0.3
## Estimated activations of one card in an Hour, for Mint Sip gold.
const MINT_SIP_TRIGGERS := 3.0

var _profile: Dictionary = DEFAULT_PROFILE
## What-if result for the board as it stands. Refreshed before each group of decisions.
var _baseline: Dictionary = {"score": 0, "gold": 0, "flavour": 0, "mult": 1.0}
## Running value of the best card in an offer. The yardstick for gold and rerolls.
var _market := 0.0


func _init() -> void:
	id = "human"


func on_run_started() -> void:
	var chef_id := GameManager.selected_chef.id if GameManager.selected_chef != null else ""
	_profile = CHEF_PROFILES.get(chef_id, DEFAULT_PROFILE)
	_market = 0.0


#region Valuation

func _hours_left() -> int:
	var later_days := maxi(0, ScoreProgression.RUN_LENGTH_ROUNDS - GameManager.current_round)
	return maxi(1, GameManager.remaining_turns + later_days * GameManager.MAX_TURNS_PER_ROUND)


func _merchants_left() -> int:
	return maxi(0, ScoreProgression.RUN_LENGTH_ROUNDS - GameManager.current_round)


## Run-score value of one coin. Half of what a typical merchant card buys per coin,
## less as gold piles up past what a visit can spend.
func _gold_value() -> float:
	return (
		_market / float(TileCard.SHOP_PRICE) * GOLD_VALUE_SHARE
		* float(_profile["gold_weight"]) * _gold_scarcity()
	)


## 1 while gold is tight, falling toward 0 as it piles up. Unspent gold at the end of the run
## is worth nothing, so a rich bot should buy anything that helps.
func _gold_scarcity() -> float:
	if _merchants_left() <= 0:
		return 0.0
	return clampf(float(GOLD_COMFORT) / float(maxi(1, EconomyManager.amount)), 0.0, 1.0)


func _refresh_baseline() -> void:
	_baseline = await runner.sim.evaluate(func() -> void: pass)


func _evaluate(change: Callable) -> float:
	var result: Dictionary = await runner.sim.evaluate(change)
	return _value_of(result)


func _value_of(result: Dictionary) -> float:
	var score_delta := float(int(result["score"]) - int(_baseline["score"]))
	var gold_delta := float(int(result["gold"]) - int(_baseline["gold"]))
	var hours := float(_hours_left())
	return score_delta * hours + gold_delta * hours * _gold_value() + _urgency(score_delta)


## Score today still needs if the board keeps scoring like the baseline.
func _shortfall() -> float:
	var projected := GameManager.total_round_score + int(_baseline["score"]) * GameManager.remaining_turns
	return maxf(0.0, float(GameManager.required_score - projected))


## Missing the goal ends the run, so closing today's gap outweighs long-term value.
func _urgency(score_delta: float) -> float:
	var shortfall := _shortfall()
	if shortfall <= 0.0 or score_delta <= 0.0:
		return 0.0
	var closes := minf(score_delta * float(GameManager.remaining_turns), shortfall)
	return closes * float(_hours_left())


func _note_market(value: float) -> void:
	if value <= 0.0:
		return
	_market = value if _market <= 0.0 else lerpf(_market, value, MARKET_SMOOTHING)


## Score one placed card added last Hour, from its own Flavour and Mult.
func _contribution(card: TileCard) -> float:
	return (
		float(card.hour_flavour_produced) * float(_baseline["mult"])
		+ card.hour_additive_mult_produced * float(_baseline["flavour"])
	)


func _one_shot_worth() -> float:
	# One Hour of a strong drink, counted again because it is saved for a day that needs it.
	return float(_baseline["score"]) * 1.5


func _pick_bias(card: TileCard) -> float:
	var bias := 1.0
	if card.type == TileCard.TileCardType.KITCHENWARE:
		bias *= float(_profile["kitchenware_pick_bias"])
	if card.has_ingredient_tag(&"beverage"):
		bias *= float(_profile["beverage_pick_bias"])
	return bias

#endregion

#region Placement

## {"hex": best Hex or null, "value": float, "net": value less the board room it uses}
func _best_placement(card: TileCard) -> Dictionary:
	var best_hex: Hex = null
	var best_value := -INF
	var best_net := -INF
	var slot_cost := _slot_cost()
	for hex: Hex in _candidate_hexes(card):
		# Only an empty spot gives up board room. A merge or replacement's what-if already prices its cost.
		var cost := slot_cost if hex.active_tile_card == null else 0.0
		var value := await _evaluate(func() -> void: card.play_on(hex, false))
		value += _station_progress_bonus(card, hex) + _meal_potential(card, hex)
		if value - cost > best_net:
			best_net = value - cost
			best_value = value
			best_hex = hex
	return {"hex": best_hex, "value": best_value, "net": best_net}


func _candidate_hexes(card: TileCard) -> Array[Hex]:
	var empty: Array[Hex] = []
	var picked: Array[Hex] = []
	var replaceable: Array[Hex] = []
	for hex: Hex in runner.legal_hexes(card):
		match card.get_overplay(hex):
			TileCard.Overplay.PLACE:
				empty.append(hex)
			TileCard.Overplay.MERGE:
				picked.append(hex)
			TileCard.Overplay.REPLACE:
				replaceable.append(hex)
	picked.append_array(_spread_by_station(empty))
	if empty.is_empty():
		replaceable.sort_custom(func(a: Hex, b: Hex) -> bool:
			return _contribution(a.active_tile_card) < _contribution(b.active_tile_card)
		)
		picked.append_array(replaceable.slice(0, MAX_REPLACE_CANDIDATES))
	return picked


func _spread_by_station(hexes_in_order: Array[Hex]) -> Array[Hex]:
	var by_segment: Dictionary = {}
	for hex: Hex in hexes_in_order:
		var segment_index: int = runner.map.get_segment_index(hex.coordinates)
		if not by_segment.has(segment_index):
			by_segment[segment_index] = [] as Array[Hex]
		by_segment[segment_index].append(hex)
	var picked: Array[Hex] = []
	for segment_index: int in by_segment:
		var hexes: Array[Hex] = by_segment[segment_index]
		if hexes.size() <= MAX_HEXES_PER_STATION:
			picked.append_array(hexes)
		else:
			picked.append(hexes[0])
			picked.append(hexes[hexes.size() - 1])
	return picked


func _meal_potential(card: TileCard, hex: Hex) -> float:
	var meal := card as MealCard
	if meal == null or meal.is_recipe_ready(hex):
		return 0.0
	var missing := meal.get_missing_card_count(hex)
	return _market * MEAL_POTENTIAL_SHARE / float(1 + missing) * _pick_bias(card)


func _station_progress_bonus(card: TileCard, hex: Hex) -> float:
	if card.type == TileCard.TileCardType.MEAL or runner.map.is_meal_slot(hex.coordinates):
		return 0.0
	var segment_index: int = runner.map.get_segment_index(hex.coordinates)
	if StationManager.get_station_type(segment_index) != null:
		return 0.0
	var cards: Array[TileCard] = runner.map.get_regular_tile_cards(segment_index)
	var before := _closest_type_missing(cards)
	cards.append(card)
	var after := _closest_type_missing(cards)
	if after >= before:
		return 0.0
	return _market * STATION_PROGRESS_SHARE / float(1 + after)


func _closest_type_missing(cards: Array[TileCard]) -> int:
	var best := 1 << 30
	for station_type: StationType in StationManager.get_station_types():
		var missing := 0
		var counts: Dictionary = station_type.missing_counts(cards)
		for tag: StringName in counts:
			missing += int(counts[tag])
		best = mini(best, missing)
	return best


func _slot_cost() -> float:
	var total := 0
	var occupied := 0
	for hex: Hex in runner.map.get_hexes_in_trigger_order():
		if hex.is_placement_blocked() and hex.active_tile_card == null:
			continue
		total += 1
		if hex.active_tile_card != null:
			occupied += 1
	if total <= 0:
		return 0.0
	return _market * SLOT_COST_SHARE * float(occupied) / float(total)


func _sell_value() -> float:
	return float(CardSellPanel.SELL_VALUE) * _gold_value()

#endregion

#region Decisions

func choose_offer(offer: Array[TileCard], is_reward: bool) -> int:
	await _refresh_baseline()
	var best_index := 0
	var best_value := -INF
	for index in offer.size():
		var card := offer[index]
		var placement := await _best_placement(card)
		var value := _sell_value()
		if placement["hex"] != null:
			value = maxf(value, float(placement["value"]))
		if value > 0.0:
			value *= _pick_bias(card)
		if value > best_value:
			best_value = value
			best_index = index
	_note_market(best_value)
	if _should_reroll(best_value, is_reward):
		return -1
	return best_index


func _should_reroll(best_value: float, is_reward: bool) -> bool:
	if not EconomyManager.can_reroll() or _market <= 0.0:
		return false
	if best_value >= _market * REROLL_BELOW_MARKET:
		return false
	# Three rerolls a day. Keep one for the day's later picks unless this one matters more.
	return is_reward or EconomyManager.rerolls_remaining >= 2 or _shortfall() > 0.0


func choose_hand_action(hand: Array[TileCard]) -> Dictionary:
	await _refresh_baseline()
	var best: Dictionary = {}
	var best_value := -INF
	var weakest: TileCard = null
	var weakest_value := INF
	for card: TileCard in hand:
		var placement := await _best_placement(card)
		var value := float(placement["net"]) if placement["hex"] != null else -INF
		if placement["hex"] != null and value > best_value:
			best_value = value
			best = {"card": card, "hex": placement["hex"]}
		if value < weakest_value:
			weakest_value = value
			weakest = card
	if _market <= 0.0:
		_note_market(best_value)
	# Holding a card costs nothing, so sell only when nothing in hand is worth a spot.
	if best.is_empty() or best_value <= 0.0:
		return {"card": weakest if weakest != null else hand[0], "sell": true}
	return best


func choose_station_perk(segment_index: int) -> int:
	var options := StationManager.get_choice_options(segment_index)
	var best_index := 0
	var best_value := -INF
	for index in options.size():
		var perk := options[index]
		var value := 0.0
		for hex: Hex in runner.map.get_hexes_in_segment(segment_index):
			var card := hex.active_tile_card
			if card == null or not perk.matches(card):
				continue
			value += (perk.output_scale - 1.0) * _contribution(card)
			value += float(perk.flat_flavour) * float(_baseline["mult"])
		if value > best_value:
			best_value = value
			best_index = index
	return best_index

#endregion

#region Staff

func on_day_started() -> void:
	await _refresh_baseline()
	# Staff act for the station in their slot. Try each seated staff member in every other slot.
	var best_move := Vector2i(-1, -1)
	var best_value := 0.0
	for from_slot in StaffManager.SLOT_COUNT:
		if StaffManager.get_staff(from_slot) == null:
			continue
		for to_slot in StaffManager.SLOT_COUNT:
			if to_slot == from_slot:
				continue
			if to_slot < from_slot and StaffManager.get_staff(to_slot) != null:
				continue
			var value := await _evaluate(func() -> void: StaffManager.move_staff(from_slot, to_slot))
			if value > best_value:
				best_value = value
				best_move = Vector2i(from_slot, to_slot)
	if best_move.x >= 0 and best_value > _market * 0.05:
		runner.move_staff(best_move.x, best_move.y)


func _staff_value(staff: StaffCard, slot: int) -> float:
	var seat := func() -> void: StaffManager.add_staff_to_slot(staff, slot)
	return await _evaluate(seat) + _day_hook_value(seat)


func _seated_staff_value(slot: int) -> float:
	var remove := func() -> void: StaffManager.slots[slot] = null
	var hour_value := -await _evaluate(remove)
	return hour_value - _day_hook_value(remove)


## Gold and condiments the roster earns from start and end of day hooks, with change applied,
## over the days left. The Hour simulation cannot see these.
func _day_hook_value(change: Callable) -> float:
	var days_left := _merchants_left()
	if days_left <= 0:
		return 0.0
	var with_change := _measure_day_hooks(change)
	var without := _measure_day_hooks(func() -> void: pass)
	var gold := float(with_change["gold"] - without["gold"])
	var condiments := float(with_change["condiments"] - without["condiments"])
	return float(days_left) * (gold * _gold_value() + condiments * _one_shot_worth())


func _measure_day_hooks(change: Callable) -> Dictionary:
	var sim: RefCounted = runner.sim
	var saved: Dictionary = sim.snapshot()
	sim.is_simulating = true
	change.call()
	var gold_before := EconomyManager.amount
	var empty_before := CondimentManager.empty_slot_count()
	StaffManager.on_day_ended()
	StaffManager.on_day_started()
	var result := {
		"gold": EconomyManager.amount - gold_before,
		"condiments": empty_before - CondimentManager.empty_slot_count(),
	}
	sim.restore(saved)
	sim.is_simulating = false
	return result

#endregion

#region Merchant

func shop(visit: RefCounted) -> void:
	await _refresh_baseline()
	var reserve := int(_profile["shop_reserve"]) if _merchants_left() > 1 else 0
	var rerolls := 0
	while true:
		var card_values: Dictionary = {}
		while true:
			var best := await _best_shop_item(visit, reserve, card_values)
			if best.is_empty():
				break
			var bought := false
			match str(best["kind"]):
				"card":
					bought = visit.buy_card(int(best["index"]))
				"staff":
					if int(best["sell_slot"]) >= 0:
						runner.sell_staff(int(best["sell_slot"]))
					bought = visit.buy_staff(int(best["index"]), int(best["slot"]))
					await _refresh_baseline()
					card_values.clear()
				"condiment":
					bought = visit.buy_condiment(int(best["index"]))
			if not bought:
				break
		var spare: int = EconomyManager.amount - reserve - GOLD_COMFORT
		var reroll_budget := clampi(MIN_MERCHANT_REROLLS + spare / 10, MIN_MERCHANT_REROLLS, MAX_MERCHANT_REROLLS)
		if rerolls >= reroll_budget:
			break
		var after_reroll: int = EconomyManager.amount - visit.reroll_cost
		if after_reroll < reserve + 2 * TileCard.SHOP_PRICE:
			break
		visit.reroll()
		rerolls += 1


## Best affordable item by value per coin, among those worth their price.
## Empty when nothing on the shelf is worth buying.
func _best_shop_item(visit: RefCounted, reserve: int, card_values: Dictionary) -> Dictionary:
	var best: Dictionary = {}
	var best_ratio := 0.0
	var spendable: int = EconomyManager.amount - reserve

	for index in visit.cards.size():
		var card: TileCard = visit.cards[index]
		if card == null or visit.price_of(card) > spendable:
			continue
		if not card_values.has(index):
			var placement := await _best_placement(card)
			var value := float(placement["value"]) if placement["hex"] != null else 0.0
			card_values[index] = value * _pick_bias(card) if value > 0.0 else value
		var ratio := _buy_ratio(float(card_values[index]), visit.price_of(card))
		if ratio > best_ratio:
			best_ratio = ratio
			best = {"kind": "card", "index": index}

	for index in visit.staff.size():
		var staff: StaffCard = visit.staff[index]
		if staff == null:
			continue
		var choice := await _staff_purchase_choice(staff)
		if choice.is_empty():
			continue
		var cost: int = visit.price_of(staff) - int(choice["refund"])
		if cost > spendable:
			continue
		var ratio := _buy_ratio(float(choice["value"]), cost)
		if ratio > best_ratio:
			best_ratio = ratio
			best = {"kind": "staff", "index": index, "slot": choice["slot"], "sell_slot": choice["sell_slot"]}

	if runner.use_condiments and CondimentManager.can_add():
		for index in visit.condiments.size():
			var condiment: Condiment = visit.condiments[index]
			if condiment == null or visit.price_of(condiment) > spendable:
				continue
			var ratio := _buy_ratio(_condiment_value(condiment), visit.price_of(condiment))
			if ratio > best_ratio:
				best_ratio = ratio
				best = {"kind": "condiment", "index": index}
	return best


## Value per coin, or 0 when the item is below the buy floor for its price.
## The floor drops as gold piles up, so a rich bot buys anything that helps.
func _buy_ratio(value: float, price: int) -> float:
	var cost := float(maxi(1, price))
	if value <= 0.0:
		return 0.0
	if value < BUY_FLOOR_SHARE * _market * cost / float(TileCard.SHOP_PRICE) * _gold_scarcity():
		return 0.0
	return value / cost


## {"slot", "sell_slot", "refund", "value"} for the best seat, or empty when it does not help.
func _staff_purchase_choice(staff: StaffCard) -> Dictionary:
	var best: Dictionary = {}
	var best_value := 0.0
	var free_slots: Array[int] = []
	for slot in StaffManager.SLOT_COUNT:
		if StaffManager.get_staff(slot) == null:
			free_slots.append(slot)
	if not free_slots.is_empty():
		for slot: int in free_slots:
			var value := await _staff_value(staff, slot)
			if value > best_value:
				best_value = value
				best = {"slot": slot, "sell_slot": -1, "refund": 0, "value": value}
		return best
	# Full roster. Replace the weakest seat if the newcomer is worth more there.
	var weakest_slot := -1
	var weakest_value := INF
	for slot in StaffManager.SLOT_COUNT:
		var value := await _seated_staff_value(slot)
		if value < weakest_value:
			weakest_value = value
			weakest_slot = slot
	if weakest_slot < 0:
		return best
	# Measured against the current roster, so the seat's old value is already subtracted.
	var replace := func() -> void: StaffManager.add_staff_to_slot(staff, weakest_slot)
	var gain := await _evaluate(replace) + _day_hook_value(replace)
	if gain <= 0.0:
		return best
	return {
		"slot": weakest_slot,
		"sell_slot": weakest_slot,
		"refund": StaffManager.get_staff(weakest_slot).get_sell_value(),
		"value": gain,
	}


func _condiment_value(condiment: Condiment) -> float:
	match condiment.effect_type:
		Condiment.EffectType.GOLD_DROP:
			return condiment.effect_value * _gold_value()
		Condiment.EffectType.CONDIMENT_PACK:
			return 3.0 * _one_shot_worth() * 0.8
		Condiment.EffectType.GARNISH, Condiment.EffectType.ECHO, \
		Condiment.EffectType.NEXT_TRIGGER_ENERGY, Condiment.EffectType.NEXT_TRIGGER_MULT:
			return _one_shot_worth()
		Condiment.EffectType.WARD:
			return _one_shot_worth() * 0.5
		Condiment.EffectType.MINT_SIP:
			return condiment.effect_value * MINT_SIP_TRIGGERS * 2.0 * _gold_value()
		Condiment.EffectType.STAR_UP, Condiment.EffectType.DUPLICATE_ORDER:
			return _market * 0.5
		Condiment.EffectType.SWAP_SPOTS, Condiment.EffectType.THROW_OUT, Condiment.EffectType.SEND_BACK:
			return _market * 0.15
	return 0.0

#endregion

#region Condiments

func before_resolve() -> void:
	if not runner.use_condiments:
		return
	for _attempt in CondimentManager.BELT_SIZE:
		if not CondimentManager.can_drink_now():
			return
		await _refresh_baseline()
		var drank := false
		for slot in CondimentManager.BELT_SIZE:
			var condiment: Condiment = CondimentManager.belt[slot]
			if condiment != null and await _try_drink(slot, condiment):
				drank = true
				break
		if not drank:
			return


func _try_drink(slot: int, condiment: Condiment) -> bool:
	match condiment.effect_type:
		Condiment.EffectType.GOLD_DROP:
			return runner.drink_condiment(slot)
		Condiment.EffectType.CONDIMENT_PACK:
			# Three new bottles need the whole belt.
			if CondimentManager.empty_slot_count() < CondimentManager.BELT_SIZE - 1:
				return false
			return runner.drink_condiment(slot)
		Condiment.EffectType.MINT_SIP:
			if _merchants_left() <= 0:
				return false
			return await _drink_on_best_target(slot)
		Condiment.EffectType.GARNISH, Condiment.EffectType.ECHO, \
		Condiment.EffectType.NEXT_TRIGGER_ENERGY, Condiment.EffectType.NEXT_TRIGGER_MULT:
			if not _should_spend_one_shot():
				return false
			return await _drink_on_best_target(slot)
		Condiment.EffectType.WARD:
			if CondimentManager.empty_slot_count() > 0:
				return false
			var top := _placed_by_contribution(true)
			if top.is_empty():
				return false
			return runner.drink_condiment(slot, top[0])
		Condiment.EffectType.SWAP_SPOTS:
			return await _drink_best_swap(slot)
		Condiment.EffectType.DUPLICATE_ORDER:
			var top := _placed_by_contribution(true)
			if top.is_empty() or not runner.board_has_room():
				return false
			return runner.drink_condiment(slot, top[0])
		Condiment.EffectType.STAR_UP:
			for hex: Hex in _placed_by_contribution(true):
				if hex.active_tile_card.star_level < TileCard.MAX_STAR_LEVEL:
					return runner.drink_condiment(slot, hex)
			return false
		Condiment.EffectType.THROW_OUT, Condiment.EffectType.SEND_BACK:
			if CondimentManager.empty_slot_count() > 0 and runner.board_has_room():
				return false
			var weakest := _weakest_card(false)
			return weakest != null and runner.drink_condiment(slot, weakest)
	return false


## One-shots are saved for a day that needs them, unless the belt is full or the run is ending.
func _should_spend_one_shot() -> bool:
	return (
		_shortfall() > 0.0
		or CondimentManager.empty_slot_count() == 0
		or GameManager.current_round >= ScoreProgression.RUN_LENGTH_ROUNDS
	)


func _drink_on_best_target(slot: int) -> bool:
	var best_hex: Hex = null
	var best_value := 0.0
	var targets := _placed_by_contribution(false)
	for index in mini(DRINK_TARGETS, targets.size()):
		var hex: Hex = targets[index]
		var result: Dictionary = await runner.sim.evaluate(
			func() -> void: CondimentManager.headless_use_slot(slot, hex)
		)
		# A drink lasts one Hour, so it is not multiplied by the Hours left.
		var score_delta := float(int(result["score"]) - int(_baseline["score"]))
		var gold_delta := float(int(result["gold"]) - int(_baseline["gold"]))
		var value := score_delta + gold_delta * _gold_value() + _urgency(score_delta)
		if value > best_value:
			best_value = value
			best_hex = hex
	if best_hex == null:
		return false
	return runner.drink_condiment(slot, best_hex)


func _drink_best_swap(slot: int) -> bool:
	var cards := _placed_by_contribution(false)
	cards.resize(mini(SWAP_CANDIDATES, cards.size()))
	var best_pair: Array[Hex] = []
	var best_value := _market * 0.3
	for i in cards.size():
		for j in range(i + 1, cards.size()):
			var a: Hex = cards[i]
			var b: Hex = cards[j]
			var value := await _evaluate(func() -> void: CondimentManager.headless_use_slot(slot, a, b))
			if value > best_value:
				best_value = value
				best_pair = [a, b]
	if best_pair.is_empty():
		return false
	return runner.drink_condiment(slot, best_pair[0], best_pair[1])


## Occupied hexes, highest last-Hour contribution first. Producers only when asked.
func _placed_by_contribution(producers_only: bool) -> Array[Hex]:
	var hexes: Array[Hex] = []
	for hex: Hex in runner.map.get_hexes_in_trigger_order():
		var card := hex.active_tile_card
		if card == null:
			continue
		if producers_only and not TileCard.is_producer_type(card.type):
			continue
		hexes.append(hex)
	hexes.sort_custom(func(a: Hex, b: Hex) -> bool:
		return _contribution(a.active_tile_card) > _contribution(b.active_tile_card)
	)
	return hexes


func _weakest_card(producers_only: bool) -> Hex:
	var hexes := _placed_by_contribution(producers_only)
	return hexes[hexes.size() - 1] if not hexes.is_empty() else null

#endregion
