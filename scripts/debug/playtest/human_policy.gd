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
	"restaurateur": {
		"kitchenware_pick_bias": 1.0,
		"beverage_pick_bias": 1.0,
		## Builds from the shop (big starting purse, free reroll), so spend freely.
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
## Moving a base station one card closer to a type is worth this share of a typical pick.
const STATION_PROGRESS_SHARE := 0.15
## Meal plans (untuned). A plan is a Meal on a Station plus the cards its recipe still needs. Its
## worth = what the Station scores with the recipe complete (a what-if Hour) x the chance those
## cards are drawn and played before the Station cooks (from the deck the player can see) x the
## times it then cooks. A Meal or Ingredient that makes a plan likelier gets the difference, so the
## bot builds Stations that cook later instead of only feeding the one cooking now.
## Share of a plan's worth a placement is credited with: plays compete with other plans.
const PLAN_SHARE := 0.7
## Throw the hand away (Discard button) when its best play is worth less than this share of a
## typical pick and the Day has discards left (untuned).
const DISCARD_BELOW_MARKET := 0.35
## A card drawn at random is worth about this share of a typical pick: what a discard's new hand
## is worth before counting the plan cards it may find (untuned).
const DISCARD_FILLER_SHARE := 0.35
## Missing today's goal ends the run, so each point that closes the gap counts this many times over
## the run-long value (untuned). With one Station cooking per Turn, a card on a Station that has
## already cooked today scores only from tomorrow; this keeps a short Day's plays on the Stations
## still to cook.
const URGENCY_WEIGHT := 4.0
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
## Gold a typical shelf card cost before the $1 card prices (untuned). The bot prices one coin from it,
## so cheaper cards do not triple what it thinks a coin is worth.
const GOLD_UNIT_PRICE := 3.0
## Gold up to about two visits of buying. Past this, each coin is worth less.
const GOLD_COMFORT := 12
## Buy a shelf item worth at least this share of a typical pick per merchant card price.
const BUY_FLOOR_SHARE := 0.3
## Estimated activations of one card in an Hour, for Mint Sip gold.
const MINT_SIP_TRIGGERS := 3.0
## Deck rules (untuned). Cards a Day draws, for how often a shuffled-in card comes up: 4 Hours of
## DeckManager.HOUR_DRAW, before any hand discards.
const DRAWS_PER_DAY := 20
## Skip a pick worth less than this share of a typical pick once the deck is this big.
const SKIP_BELOW_MARKET := 0.2
const SKIP_DECK_SIZE := 18
## Use the removal service on cards worth less than this share of a typical pick while the deck
## is above REMOVAL_DECK_TARGET. At most MAX_REMOVALS_PER_VISIT per visit.
const REMOVE_BELOW_MARKET := 0.1
const REMOVAL_DECK_TARGET := 18
const MAX_REMOVALS_PER_VISIT := 2
const REMOVAL_CANDIDATES := 8
## Pay for a card-pick reroll only when the best card is worth less than this share of a typical pick.
const PAID_REROLL_BELOW_MARKET := 0.3

var _profile: Dictionary = DEFAULT_PROFILE
## What-if result for the board as it stands, one per Station (segment index): only one Station
## cooks an Hour (HexTileMap.get_cooking_segment), so each is resolved on its own. Refreshed before
## each group of decisions.
var _baselines: Array[Dictionary] = []
## The cooking Station's baseline (this Hour's Station), for the one-Hour estimates.
var _baseline: Dictionary = {"score": 0, "gold": 0, "flavour": 0, "mult": 1.0}
## Hex coordinates -> score a placed card added the last time its Station was resolved.
var _contributions: Dictionary = {}
## Running value of the best card in an offer or hand, run-long value only (today's urgency left
## out, or Day 1's first hand would set the yardstick for gold and Meal bonuses at many times a
## card's real worth). The yardstick for gold and rerolls.
var _market := 0.0
## Urgency counted by _value_of since the last reset, so a placement can report its share.
var _urgency_seen := 0.0
## Meal plans for the board as it stands, built lazily per decision ("<segment>|<meal id>" -> plan).
var _plans: Dictionary = {}


func _init() -> void:
	id = "human"


func on_run_started() -> void:
	var chef_id := GameManager.selected_chef.id if GameManager.selected_chef != null else ""
	_profile = CHEF_PROFILES.get(chef_id, DEFAULT_PROFILE)
	_market = 0.0
	_baselines.clear()
	_contributions.clear()


func capture_state() -> Dictionary:
	var baselines: Array = []
	for baseline: Dictionary in _baselines:
		baselines.append(baseline.duplicate())
	return {
		"baseline": _baseline.duplicate(),
		"baselines": baselines,
		"contributions": _contributions.duplicate(),
		"market": _market,
	}


func restore_state(state: Dictionary) -> void:
	_baseline = (state["baseline"] as Dictionary).duplicate()
	_baselines.clear()
	for baseline: Dictionary in state.get("baselines", []):
		_baselines.append(baseline.duplicate())
	_contributions = (state.get("contributions", {}) as Dictionary).duplicate()
	_market = float(state["market"])


#region Valuation

func _hours_left() -> int:
	var later_days := maxi(0, ScoreProgression.RUN_LENGTH_ROUNDS - GameManager.current_round)
	return maxi(1, GameManager.remaining_turns + later_days * GameManager.MAX_TURNS_PER_ROUND)


func _merchants_left() -> int:
	return maxi(0, ScoreProgression.RUN_LENGTH_ROUNDS - GameManager.current_round)


func _segment_count() -> int:
	return maxi(1, runner.map.get_segment_count())


## The Station this Hour cooks.
func _cooking_segment() -> int:
	return runner.map.get_cooking_segment_for_hour(GameManager.get_turn_number())


## True when the Station still cooks today: this Hour's Station or one a later Hour of the Day
## cooks (Rush Hour's 3 Hours never reach the bottom Station). A Day that meets its goal early
## ends before the rest cook; the bot does not guess that.
func _cooks_today(segment: int) -> bool:
	var last_hour := GameManager.get_max_turns_per_round()
	for hour in range(GameManager.get_turn_number(), last_hour + 1):
		if runner.map.get_cooking_segment_for_hour(hour) == segment:
			return true
	return false


## Times the Station still cooks this run: today if it has not cooked yet, then once each later Day.
func _cooks_left(segment: int) -> float:
	var later_days := maxi(0, ScoreProgression.RUN_LENGTH_ROUNDS - GameManager.current_round)
	return float(later_days) + (1.0 if _cooks_today(segment) else 0.0)


func _all_segments() -> Array[int]:
	var segments: Array[int] = []
	for segment in _segment_count():
		segments.append(segment)
	return segments


func _segment_of(hex: Hex) -> int:
	return runner.map.get_segment_index(hex.coordinates)


## Run-score value of one coin. Half of what a typical merchant card buys per coin,
## less as gold piles up past what a visit can spend.
func _gold_value() -> float:
	return (
		_market / GOLD_UNIT_PRICE * GOLD_VALUE_SHARE
		* float(_profile["gold_weight"]) * _gold_scarcity()
	)


## 1 while gold is tight, falling toward 0 as it piles up. Unspent gold at the end of the run
## is worth nothing, so a rich bot should buy anything that helps.
func _gold_scarcity() -> float:
	if _merchants_left() <= 0:
		return 0.0
	return clampf(float(GOLD_COMFORT) / float(maxi(1, EconomyManager.amount)), 0.0, 1.0)


## Resolves every Station as the board stands (one what-if Hour each) and notes what each placed
## card added.
func _refresh_baseline() -> void:
	_baselines.clear()
	_contributions.clear()
	_plans.clear()
	for segment in _segment_count():
		var produced: Dictionary = {}
		var read := func() -> void:
			for hex: Hex in runner.map.get_hexes_in_segment(segment):
				var card := hex.active_tile_card
				if card != null:
					produced[hex.coordinates] = [float(card.hour_flavour_produced), float(card.hour_additive_mult_produced)]
		var result: Dictionary = await runner.sim.evaluate(func() -> void: pass, segment, read)
		_baselines.append(result)
		for coords: Vector2i in produced:
			var pair: Array = produced[coords]
			_contributions[coords] = float(pair[0]) * float(result["mult"]) + float(pair[1]) * float(result["flavour"])
	var current := clampi(_cooking_segment(), 0, _baselines.size() - 1)
	_baseline = _baselines[current]


func _baseline_for(segment: int) -> Dictionary:
	if segment < 0 or segment >= _baselines.size():
		return _baseline
	return _baselines[segment]


## Value of a change over the rest of the run. segments are the Stations it can touch (a placement:
## its own Station); empty means every Station (staff, swaps). Each is resolved as its own Hour and
## counted once for every time that Station still cooks.
func _evaluate(change: Callable, segments: Array[int] = []) -> float:
	var targets := segments if not segments.is_empty() else _all_segments()
	var total := 0.0
	for segment: int in targets:
		var result: Dictionary = await runner.sim.evaluate(change, segment)
		total += _value_of(result, segment)
	return total


func _value_of(result: Dictionary, segment: int) -> float:
	var base := _baseline_for(segment)
	var score_delta := float(int(result["score"]) - int(base["score"]))
	var gold_delta := float(int(result["gold"]) - int(base["gold"]))
	var cooks := _cooks_left(segment)
	var urgency := _urgency(score_delta) if _cooks_today(segment) else 0.0
	_urgency_seen += urgency
	return score_delta * cooks + gold_delta * cooks * _gold_value() + urgency


## Score today still needs if every Station still to cook scores like its baseline.
func _shortfall() -> float:
	var projected := float(GameManager.total_round_score)
	for segment in _baselines.size():
		if _cooks_today(segment):
			projected += float(int(_baselines[segment]["score"]))
	return maxf(0.0, float(GameManager.required_score) - projected)


## Missing the goal ends the run, so closing today's gap outweighs long-term value.
func _urgency(score_delta: float) -> float:
	var shortfall := _shortfall()
	if shortfall <= 0.0 or score_delta <= 0.0:
		return 0.0
	var closes := minf(score_delta, shortfall)
	return closes * float(_hours_left()) * URGENCY_WEIGHT


func _note_market(value: float) -> void:
	if value <= 0.0:
		return
	_market = value if _market <= 0.0 else lerpf(_market, value, MARKET_SMOOTHING)


## Score the card on this hex added the last time its Station was resolved, from its own Flavour
## and Mult.
func _contribution(hex: Hex) -> float:
	return float(_contributions.get(hex.coordinates, 0.0))


func _one_shot_worth() -> float:
	# One Hour of a strong drink, counted again because it is saved for a day that needs it.
	# A typical Station's Hour, since a drink can be saved for whichever Station cooks.
	if _baselines.is_empty():
		return float(_baseline["score"]) * 1.5
	var total := 0.0
	for baseline: Dictionary in _baselines:
		total += float(int(baseline["score"]))
	return total / float(_baselines.size()) * 1.5


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
	var best_urgency := 0.0
	var slot_cost := _slot_cost()
	for hex: Hex in _candidate_hexes(card):
		# Only an empty spot gives up board room. A merge or replacement's what-if already prices its cost.
		var cost := slot_cost if hex.active_tile_card == null else 0.0
		_urgency_seen = 0.0
		var value := await _evaluate(func() -> void: card.play_on(hex, false), [_segment_of(hex)] as Array[int])
		var urgency := _urgency_seen
		value += _station_progress_bonus(card, hex) + _unique_meal_gold(card)
		value += await _plan_bonus(card, hex)
		if value - cost > best_net:
			best_net = value - cost
			best_value = value
			best_hex = hex
			best_urgency = urgency
	return {"hex": best_hex, "value": best_value, "net": best_net, "urgency": best_urgency}


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
			return _contribution(a) < _contribution(b)
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


#region Meal plans

## Plan bonus for placing card on hex: for a Meal, the worth of its plan on that Station; for an
## Ingredient or Kitchenware, how much likelier it makes the plans of the Station's waiting Meals
## and of the Meals in hand that could go there. A recipe it completes on the spot is left to the
## what-if Hour, which already serves the Meal.
func _plan_bonus(card: TileCard, hex: Hex) -> float:
	var segment := _segment_of(hex)
	var meal := card as MealCard
	if meal != null:
		if not runner.map.is_meal_slot(hex.coordinates) or meal.is_recipe_ready(hex):
			return 0.0
		var plan: Dictionary = await _plan_for(segment, meal, hex)
		# Every plan counts on the same draws, plays and discards: a new Meal is credited less for
		# each plan on the board still short of its recipe.
		return _plan_share() * _plan_ev(plan, _scenario_now(), []) / float(1 + _open_plan_count())
	if runner.map.is_meal_slot(hex.coordinates) or hex.active_tile_card != null:
		return 0.0
	var bonus := 0.0
	for plan: Dictionary in await _plans_on(segment):
		var before := _plan_ev(plan, _scenario_now(), [])
		var after := _plan_ev(plan, _scenario_now(), [card])
		bonus += maxf(0.0, after - before)
	return _plan_share() * bonus


## Meals on the board still short of their recipe.
func _open_plan_count() -> int:
	var count := 0
	for hex: Hex in runner.map.get_hexes_in_trigger_order():
		var meal := hex.active_tile_card as MealCard
		if meal != null and not meal.is_recipe_ready(hex):
			count += 1
	return count


## Share of a plan's worth this player credits. A subclass that plans less can lower it.
func _plan_share() -> float:
	return PLAN_SHARE


## Plans a Station can hold: its own Meals still short of their recipe, and each Meal in hand that
## has a free Meal slot there.
func _plans_on(segment: int) -> Array[Dictionary]:
	var plans: Array[Dictionary] = []
	var seen: Dictionary = {}
	for meal_hex: Hex in runner.map.get_hexes_in_segment(segment):
		var meal := meal_hex.active_tile_card as MealCard
		if meal != null and not meal.is_recipe_ready(meal_hex):
			seen[meal.id] = true
			plans.append(await _plan_for(segment, meal, meal_hex))
	for card: TileCard in DeckManager.hand:
		var meal := card as MealCard
		if meal == null or seen.has(meal.id):
			continue
		var slot := _free_meal_slot(meal, segment)
		if slot == null:
			continue
		seen[meal.id] = true
		plans.append(await _plan_for(segment, meal, slot))
	return plans


func _free_meal_slot(meal: MealCard, segment: int) -> Hex:
	for hex: Hex in runner.map.get_hexes_in_segment(segment):
		if runner.map.is_meal_slot(hex.coordinates) and hex.active_tile_card == null and meal.can_play_on(hex):
			return hex
	return null


## {segment, meal_id, placed (Meal already on its slot), needs: Array of {"id"} or {"tag"},
## worth: score (and gold) the Station adds when it cooks with the recipe complete}. worth 0 when the
## Station has no room for the missing cards or nothing in the deck can fill them.
func _plan_for(segment: int, meal: MealCard, slot: Hex) -> Dictionary:
	var key := "%d|%s" % [segment, meal.id]
	if _plans.has(key):
		return _plans[key]
	var plan := {"segment": segment, "meal_id": meal.id, "placed": slot.active_tile_card != null,
		"needs": _recipe_needs(meal, segment), "worth": 0.0}
	var empty: Array[Hex] = []
	for hex: Hex in runner.map.get_hexes_in_segment(segment):
		if not runner.map.is_meal_slot(hex.coordinates) and hex.active_tile_card == null and not hex.is_placement_blocked():
			empty.append(hex)
	var fillers := _filler_cards(plan["needs"])
	if fillers.size() == (plan["needs"] as Array).size() and fillers.size() <= empty.size():
		var placed: bool = plan["placed"]
		var change := func() -> void:
			if not placed:
				meal.play_on(slot, false)
			for index in fillers.size():
				fillers[index].play_on(empty[index], false)
		var result: Dictionary = await runner.sim.evaluate(change, segment)
		var base := _baseline_for(segment)
		plan["worth"] = maxf(0.0, float(int(result["score"]) - int(base["score"]))
			+ float(int(result["gold"]) - int(base["gold"])) * _gold_value())
	_plans[key] = plan
	return plan


## What the recipe still lacks on this Station, by printed cards: named cards first, then kinds.
## Kinds a Kitchenware lends are not counted on, so a plan never relies on a status.
func _recipe_needs(meal: MealCard, segment: int) -> Array[Dictionary]:
	var cards: Array[TileCard] = runner.map.get_regular_tile_cards(segment)
	var needs: Array[Dictionary] = []
	for card_id: String in meal.recipe_required_card_ids:
		if not cards.any(func(card: TileCard) -> bool: return card.id == card_id):
			needs.append({"id": card_id})
	var counts: Dictionary = meal.get_recipe_kind_counts()
	for tag: StringName in counts:
		var missing: int = meal._missing_for_tag(cards, tag)
		for i in missing:
			needs.append({"tag": tag})
	return needs


func _fills(card: TileCard, need: Dictionary) -> bool:
	if need.has("id"):
		return card.id == String(need["id"])
	return TileCard.matches_kind_filter(card, need["tag"], false)


## One deck card for each need (hand first, then the draw pile, then the rest of the deck), for the
## what-if that prices the complete recipe. Fewer than the needs when the deck can't fill them.
func _filler_cards(needs: Array) -> Array[TileCard]:
	var pool: Array[TileCard] = []
	pool.append_array(DeckManager.hand)
	pool.append_array(DeckManager.draw_pile)
	pool.append_array(DeckManager.discard_pile)
	pool.append_array(DeckManager.played_pile)
	var used: Dictionary = {}
	var picked: Array[TileCard] = []
	for need: Dictionary in needs:
		for card: TileCard in pool:
			if not used.has(card) and card.type != TileCard.TileCardType.MEAL and _fills(card, need):
				used[card] = true
				picked.append(card)
				break
	return picked


## Draws and plays the player still has, as one dictionary: the hand, the draw pile, plays left this
## Hour and the Day's hand discards. A discard what-if empties the hand and draws again.
func _scenario_now() -> Dictionary:
	return {
		"hand": DeckManager.hand.duplicate(),
		"pile": DeckManager.draw_pile.duplicate(),
		"plays_left": DeckManager.plays_left(),
		# A player who doesn't use the Discard button yet gets no extra draws from it.
		"discards_left": DeckManager.discards_left if _may_discard() else 0,
		"extra_draws": 0,
	}


func _scenario_after_discard() -> Dictionary:
	var scenario := _scenario_now()
	var hand_size: int = (scenario["hand"] as Array).size()
	scenario["hand"] = [] as Array[TileCard]
	scenario["discards_left"] = maxi(0, int(scenario["discards_left"]) - 1)
	scenario["extra_draws"] = hand_size
	return scenario


## Expected worth of a plan over the rest of the run. placed_now: cards assumed played this Hour
## (the card being valued), which fill needs for free (their play is already being spent).
func _plan_ev(plan: Dictionary, scenario: Dictionary, placed_now: Array) -> float:
	var worth := float(plan["worth"])
	if worth <= 0.0:
		return 0.0
	var segment: int = plan["segment"]
	var needs: Array = (plan["needs"] as Array).duplicate()
	for card: TileCard in placed_now:
		for i in needs.size():
			if _fills(card, needs[i]):
				needs.remove_at(i)
				break
	var meal_play := 0 if bool(plan["placed"]) else 1
	var today := _cooks_today(segment)
	var cooks := _cooks_left(segment)
	var p_today := 0.0
	if today:
		p_today = _p_complete_today(plan, needs, meal_play, segment, scenario, placed_now.size())
	var p_later := _p_complete_tomorrow(plan, needs, meal_play, segment)
	var later_cooks := maxf(0.0, cooks - (1.0 if today else 0.0))
	var ev := p_today * worth * cooks + (1.0 - p_today) * p_later * worth * later_cooks
	if today:
		ev += _urgency(p_today * worth)
	return ev


## Chance every need is drawn and played on this Station before it cooks today.
func _p_complete_today(plan: Dictionary, needs: Array, meal_play: int, segment: int, scenario: Dictionary, used_plays: int) -> float:
	var hours_after := segment + 1 - GameManager.get_turn_number()
	var plays := int(scenario["plays_left"]) - used_plays + hours_after * DeckManager.PLAYS_PER_HOUR
	if meal_play > 0 and not _hand_has(scenario, String(plan["meal_id"])):
		return 0.0
	if needs.size() + meal_play > plays:
		return 0.0
	var draws := hours_after * DeckManager.HOUR_DRAW + int(scenario["extra_draws"]) \
		+ int(scenario["discards_left"]) * DeckManager.HOUR_DRAW / 2
	var pile: Array = scenario["pile"]
	var hand: Array = (scenario["hand"] as Array).duplicate()
	var chance := 1.0
	var taken: Dictionary = {}
	for need: Dictionary in needs:
		var in_hand := -1
		for i in hand.size():
			if _fills(hand[i], need):
				in_hand = i
				break
		if in_hand >= 0:
			hand.remove_at(in_hand)
			continue
		var copies := 0
		for card: TileCard in pile:
			if not taken.has(card) and _fills(card, need):
				copies += 1
		if copies == 0:
			return 0.0
		chance *= _p_drawn(copies, draws, pile.size())
		# Leave one copy for this need, so a second need of the same kind sees one fewer.
		for card: TileCard in pile:
			if not taken.has(card) and _fills(card, need):
				taken[card] = true
				break
	return chance


## Chance every need (and the Meal, if it isn't placed) turns up before the Station cooks on a
## later Day, from the whole reshuffled deck.
func _p_complete_tomorrow(plan: Dictionary, needs: Array, meal_play: int, segment: int) -> float:
	if _merchants_left() <= 0:
		return 0.0
	var hours := segment + 1
	if needs.size() + meal_play > hours * DeckManager.PLAYS_PER_HOUR:
		return 0.0
	var deck := DeckManager.all_cards()
	var discards := DeckManager.HAND_DISCARDS_PER_DAY if _may_discard() else 0
	var draws := hours * DeckManager.HOUR_DRAW + discards * DeckManager.HOUR_DRAW / 2
	var chance := 1.0
	var all_needs: Array = needs.duplicate()
	if meal_play > 0:
		all_needs.append({"id": plan["meal_id"]})
	var taken: Dictionary = {}
	for need: Dictionary in all_needs:
		var copies := 0
		for card: TileCard in deck:
			if not taken.has(card) and _fills(card, need):
				copies += 1
		if copies == 0:
			return 0.0
		chance *= _p_drawn(copies, draws, deck.size())
		for card: TileCard in deck:
			if not taken.has(card) and _fills(card, need):
				taken[card] = true
				break
	return chance


func _hand_has(scenario: Dictionary, card_id: String) -> bool:
	for card: TileCard in scenario["hand"]:
		if card.id == card_id:
			return true
	return false


## Chance at least one of copies cards is among draws cards taken from a pile of pile_size.
func _p_drawn(copies: int, draws: int, pile_size: int) -> float:
	if copies <= 0 or draws <= 0 or pile_size <= 0:
		return 0.0
	if draws >= pile_size:
		return 1.0
	var miss := 1.0
	for i in draws:
		var left := pile_size - i
		miss *= float(maxi(0, left - copies)) / float(left)
		if miss <= 0.0:
			return 1.0
	return 1.0 - miss


## What a discard is worth for the Day's plans: the extra draws it buys, less the hand it throws
## away. Every plan on the board and in hand is counted.
func _discard_plan_gain() -> float:
	var gain := 0.0
	var now := _scenario_now()
	var after := _scenario_after_discard()
	for segment in _segment_count():
		for plan: Dictionary in await _plans_on(segment):
			gain += _plan_ev(plan, after, []) - _plan_ev(plan, now, [])
	return gain

#endregion


## Day-end Gold for each different Meal on the board (EconomyManager.GOLD_PER_UNIQUE_MEAL): a Meal
## whose id is not on the board yet pays it every Day it stays, today included.
func _unique_meal_gold(card: TileCard) -> float:
	if card.type != TileCard.TileCardType.MEAL:
		return 0.0
	for hex: Hex in runner.map.get_hexes_in_trigger_order():
		if hex.active_tile_card != null and hex.active_tile_card.id == card.id:
			return 0.0
	var days := float(_merchants_left() + 1)
	return float(EconomyManager.GOLD_PER_UNIQUE_MEAL) * days * _gold_value()


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


## A shuffled-in card is drawn about this often a Day: 1 while the deck is small, less as it grows.
func _deck_draw_share() -> float:
	return clampf(float(DRAWS_PER_DAY) / float(maxi(1, DeckManager.deck_size() + 1)), 0.25, 1.0)

#endregion

#region Decisions

func choose_offer(offer: Array[TileCard], is_reward: bool) -> int:
	await _refresh_baseline()
	var best_index := 0
	var best_value := -INF
	for index in offer.size():
		var card := offer[index]
		var placement := await _best_placement(card)
		var value := 0.0
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
	# A weak card only thins the deck's draws, so pass on it once the deck is big enough.
	if best_value <= 0.0 or (DeckManager.deck_size() >= SKIP_DECK_SIZE and best_value < _market * SKIP_BELOW_MARKET):
		return runner.SKIP_PICK
	return best_index


func _should_reroll(best_value: float, is_reward: bool) -> bool:
	if not EconomyManager.can_reroll() or _market <= 0.0:
		return false
	if best_value >= _market * REROLL_BELOW_MARKET:
		return false
	# Picks only come at the end of the Day, so free rerolls are always worth using.
	var cost := EconomyManager.get_reroll_cost()
	if cost == 0:
		return true
	# A paid reroll's price climbs for the rest of the run: pay only for a weak offer,
	# and keep enough Gold for the Merchant.
	return is_reward and best_value < _market * PAID_REROLL_BELOW_MARKET \
		and EconomyManager.amount - cost >= int(_profile["shop_reserve"]) + TileCard.SHOP_PRICE


func choose_hand_action(hand: Array[TileCard]) -> Dictionary:
	await _refresh_baseline()
	var best: Dictionary = {}
	var best_value := -INF
	var best_long_value := 0.0
	var nets: Array[float] = []
	for card: TileCard in hand:
		var placement := await _best_placement(card)
		var value := float(placement["net"]) if placement["hex"] != null else -INF
		nets.append(maxf(0.0, value))
		if placement["hex"] != null and value > best_value:
			best_value = value
			best_long_value = float(placement["value"]) - float(placement["urgency"])
			best = {"card": card, "hex": placement["hex"]}
	# With no card picks the hand is where the bot sees cards, so it keeps the yardstick current.
	_note_market(best_long_value)
	# A weak hand: throw it away for a new one while the Day has discards (no play used), else end
	# the Hour when nothing is worth a spot, since unplayed cards are only discarded. Untuned.
	var weak := best.is_empty() or best_value <= 0.0 or best_value < _market * DISCARD_BELOW_MARKET
	if _may_discard() and DeckManager.can_discard_hand():
		if weak:
			return {"discard": true}
		# Searching: a new hand is worth a few ordinary cards plus the better odds of drawing what
		# the Day's Meal plans still lack; keep the hand when its best plays are worth more.
		nets.sort()
		nets.reverse()
		var keep := 0.0
		for i in mini(DeckManager.plays_left(), nets.size()):
			keep += nets[i]
		var search := float(DeckManager.plays_left()) * _market * DISCARD_FILLER_SHARE
		search += await _discard_plan_gain()
		if search > keep:
			_log_search_discard()
			return {"discard": true}
	if best.is_empty() or best_value <= 0.0:
		return {"end": true}
	return best


## Counts discards taken to search for plan cards (details.search_discards).
func _log_search_discard() -> void:
	runner.note_search_discard()


## Whether this bot thinks of the Discard button. A subclass can say no.
func _may_discard() -> bool:
	return true


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
			value += (perk.output_scale - 1.0) * _contribution(hex)
			value += float(perk.flat_flavour) * float(_baseline_for(segment_index)["mult"])
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
	await _use_removal_service(visit, reserve)
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
				"pack":
					bought = await _open_and_keep_pack(visit, int(best["index"]))
					# A kept Technique changes the roster, so every estimate is stale.
					await _refresh_baseline()
					card_values.clear()
			if not bought:
				break
		var spare: int = EconomyManager.amount - reserve - GOLD_COMFORT
		var reroll_budget := clampi(MIN_MERCHANT_REROLLS + spare / 10, MIN_MERCHANT_REROLLS, MAX_MERCHANT_REROLLS)
		if rerolls >= reroll_budget:
			break
		var after_reroll: int = EconomyManager.amount - visit.next_reroll_cost()
		if after_reroll < reserve + 2 * TileCard.SHOP_PRICE:
			break
		if not _may_reroll_shop():
			break
		visit.reroll()
		rerolls += 1


## Takes the weakest deck cards out while the deck is big and gold allows. The weakest card is the
## one whose best play now is worth least.
func _use_removal_service(visit: RefCounted, reserve: int) -> void:
	for _removal in MAX_REMOVALS_PER_VISIT:
		if DeckManager.deck_size() <= REMOVAL_DECK_TARGET or not DeckManager.can_remove_card():
			return
		if EconomyManager.amount - DeckManager.removal_price() < reserve + TileCard.SHOP_PRICE:
			return
		var weakest: TileCard = null
		var weakest_value := INF
		for card: TileCard in _removal_candidates():
			var placement := await _best_placement(card)
			var value := float(placement["net"]) if placement["hex"] != null else -INF
			if value < weakest_value:
				weakest_value = value
				weakest = card
		if weakest == null or weakest_value >= _market * REMOVE_BELOW_MARKET:
			return
		if not visit.remove_deck_card(weakest):
			return


## One deck card per id, those with no copy on the board first (a copy there can still merge),
## at most REMOVAL_CANDIDATES of them so a visit stays cheap.
func _removal_candidates() -> Array[TileCard]:
	var on_board: Array[String] = []
	for hex: Hex in runner.map.get_hexes_in_trigger_order():
		if hex.active_tile_card != null:
			on_board.append(String(hex.active_tile_card.id))
	var loose: Array[TileCard] = []
	var placed: Array[TileCard] = []
	var seen: Array[String] = []
	for card: TileCard in DeckManager.all_cards():
		if String(card.id) in seen:
			continue
		seen.append(String(card.id))
		if String(card.id) in on_board:
			placed.append(card)
		else:
			loose.append(card)
	loose.append_array(placed)
	return loose.slice(0, REMOVAL_CANDIDATES)


## Whether this bot thinks of rerolling the shelf. A subclass can say no.
func _may_reroll_shop() -> bool:
	return true


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
			# Bought cards are shuffled into the deck, so they come up less often than a pick.
			value *= _deck_draw_share()
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

	for index in visit.packs.size():
		if not visit.can_open_pack(index) or visit.pack_price(index) > spendable:
			continue
		var pack_key := "pack%d" % index
		if not card_values.has(pack_key):
			card_values[pack_key] = await _pack_value(visit, index)
		var ratio := _buy_ratio(float(card_values[pack_key]), visit.pack_price(index))
		if ratio > best_ratio:
			best_ratio = ratio
			best = {"kind": "pack", "index": index}
	return best


## What opening a pack is worth: the buyer keeps the best card, so the best of a preview draw.
## The preview is not the pack's real contents, so the bot buys on the odds like a player would.
func _pack_value(visit: RefCounted, index: int) -> float:
	var best_value := 0.0
	for card: Card in visit.preview_pack(index):
		var kept: Dictionary = await _kept_card_choice(card)
		best_value = maxf(best_value, float(kept["value"]))
	return best_value


## {"value", "slot"} for keeping this card from a pack. slot is the Technique seat, else -1.
func _kept_card_choice(card: Card) -> Dictionary:
	if card is StaffCard:
		var choice := await _staff_purchase_choice(card as StaffCard)
		if choice.is_empty():
			return {"value": 0.0, "slot": StaffManager.first_free_slot()}
		return {"value": float(choice["value"]), "slot": int(choice["slot"])}
	var tile_card := card as TileCard
	var placement := await _best_placement(tile_card)
	var value := 0.0
	if placement["hex"] != null:
		value = maxf(value, float(placement["value"])) * _deck_draw_share()
	if value > 0.0:
		value *= _pick_bias(tile_card)
	return {"value": value, "slot": -1}


## Pays for a pack, then keeps the best card it really holds. False when it could not be opened.
func _open_and_keep_pack(visit: RefCounted, index: int) -> bool:
	var contents: Array[Card] = visit.open_pack(index)
	if contents.is_empty():
		return false
	var best_card: Card = contents[0]
	var best_value := -INF
	var best_slot := -1
	for card in contents:
		var kept: Dictionary = await _kept_card_choice(card)
		if float(kept["value"]) > best_value:
			best_value = float(kept["value"])
			best_card = card
			best_slot = int(kept["slot"])
	visit.keep_from_pack(best_card, best_slot)
	return true


## Value per coin, or 0 when the item is below the buy floor for its price.
## The floor drops as gold piles up, so a rich bot buys anything that helps.
func _buy_ratio(value: float, price: int) -> float:
	var cost := float(maxi(1, price))
	if value <= 0.0:
		return 0.0
	if value < BUY_FLOOR_SHARE * _market * cost / GOLD_UNIT_PRICE * _gold_scarcity():
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
		Condiment.EffectType.GOLD_PER_UNIQUE_MEAL:
			return condiment.effect_value * float(EconomyManager.count_unique_board_meals()) * _gold_value()
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
		Condiment.EffectType.GOLD_PER_UNIQUE_MEAL:
			if EconomyManager.count_unique_board_meals() <= 0:
				return false
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
			var starred := _placed_by_contribution(true)
			if starred.is_empty():
				return false
			return runner.drink_condiment(slot, starred[0])
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
	# A drink lasts one Hour and only the cooking Station scores in it, so only its cards are targets.
	var cooking := _cooking_segment()
	var targets: Array[Hex] = []
	for hex: Hex in _placed_by_contribution(false):
		if _segment_of(hex) == cooking:
			targets.append(hex)
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
		return _contribution(a) > _contribution(b)
	)
	return hexes


func _weakest_card(producers_only: bool) -> Hex:
	var hexes := _placed_by_contribution(producers_only)
	return hexes[hexes.size() - 1] if not hexes.is_empty() else null

#endregion
