extends "res://scripts/debug/playtest/human_policy.gd"

## A player who is still learning the game. It sees what the human bot sees (every option is tried
## as a what-if Hour with the real rules) but three things keep it from playing well:
##
##   Knowledge gaps  Before its "discovery day" it does not use a mechanic at all: merging a card
##                   onto its copy, replacing a card, rerolling, drinking condiments, moving staff.
##                   Each run draws the day it notices each one. The lower the skill, the later.
##   Misjudgment     Every what-if value is perceived with noise, so it mis-ranks cards, spots,
##                   shop items and drinks, and buys things a careful player would skip.
##   Slips           Now and then it acts without weighing anything: grabs a card, drops one on
##                   a random spot, sells the wrong one, walks out of the merchant, forgets the belt
##                   or picks a station perk blind.
##
## Skill grows by `learning` each Day, which shrinks the noise and the slips. Profiles:
##   novice  starts low and learns quickly   casual  middling   slip  knows the game, makes mistakes
## --skill and --learning override a profile. Every roll comes from a seeded stream, so a seed
## replays the same way. All numbers are untuned.

const PROFILES := {
	"novice": {"skill": 0.25, "learning": 0.05},
	"casual": {"skill": 0.55, "learning": 0.03},
	"slip": {"skill": 0.85, "learning": 0.0},
}
## Share of decisions that slip at skill 0. Falls to 0 at skill 1.
const MAX_SLIP_RATE := 0.5
## Spread of the value noise at skill 0 (log-normal sigma). Falls to 0 at skill 1.
const MAX_NOISE := 1.0
## Discovery days run from Day 1 to Day 1 + (1 - skill) x this.
const DISCOVERY_SPAN := 9.0
## Chance of acting on a reroll idea at skill 0, rising to 1 at skill 1.
const REROLL_NERVE_MIN := 0.4
const MECHANICS: Array[String] = ["merge", "replace", "reroll", "condiments", "staff"]

var _profile_name := "novice"
var _skill_start := 0.25
var _learning := 0.05
var _step := 0
## Mechanic -> first Day this player uses it.
var _known_from: Dictionary = {}
## Slip kind -> how many times it happened this run.
var _slips: Dictionary = {}


## Call right after new(). A negative override keeps the profile's value.
func configure(profile_name: String, skill_override := -1.0, learning_override := -1.0) -> void:
	_profile_name = profile_name if PROFILES.has(profile_name) else "novice"
	var preset: Dictionary = PROFILES[_profile_name]
	_skill_start = clampf(skill_override if skill_override >= 0.0 else float(preset["skill"]), 0.0, 1.0)
	_learning = maxf(0.0, learning_override if learning_override >= 0.0 else float(preset["learning"]))
	id = _profile_name


func on_run_started() -> void:
	super.on_run_started()
	_step = 0
	_slips = {}
	var rng := RunRng.create_rng("novice:knowledge")
	for mechanic: String in MECHANICS:
		_known_from[mechanic] = 1 + int(rng.randf() * (1.0 - _skill_start) * DISCOVERY_SPAN)


func capture_state() -> Dictionary:
	var state := super.capture_state()
	state["step"] = _step
	state["slips"] = _slips.duplicate()
	return state


func restore_state(state: Dictionary) -> void:
	super.restore_state(state)
	_step = int(state["step"])
	_slips = (state["slips"] as Dictionary).duplicate()


func describe() -> Dictionary:
	return {
		"profile": _profile_name,
		"skill_start": _skill_start,
		"learning": _learning,
		"skill_end": _skill(),
		"known_from": _known_from.duplicate(),
		"slips": _slips.duplicate(),
	}


#region Skill

## Skill today: the starting skill plus what this player has learned over the Days played.
func _skill() -> float:
	return clampf(_skill_start + _learning * float(GameManager.current_round - 1), 0.0, 1.0)


func _knows(mechanic: String) -> bool:
	return GameManager.current_round >= int(_known_from.get(mechanic, 1))


func _rng() -> RandomNumberGenerator:
	_step += 1
	return RunRng.create_rng("novice:%d" % _step)


## True when this decision slips. weight makes a kind of decision slip more or less often.
func _slip(kind: String, weight := 1.0) -> bool:
	var rate := minf(0.9, MAX_SLIP_RATE * (1.0 - _skill()) * weight)
	if _rng().randf() >= rate:
		return false
	_slips[kind] = int(_slips.get(kind, 0)) + 1
	return true


## The human bot's what-if value as this player perceives it.
func _evaluate(change: Callable) -> float:
	var value: float = await super._evaluate(change)
	var sigma := MAX_NOISE * (1.0 - _skill())
	if sigma <= 0.0:
		return value
	var rng := _rng()
	return value * exp(sigma * rng.randfn()) + 0.25 * sigma * _market * rng.randfn()


## Spots this player would think of for a card: no merging or replacing until it has found out.
func _filter_known(hexes: Array[Hex], card: TileCard) -> Array[Hex]:
	var kept: Array[Hex] = []
	for hex: Hex in hexes:
		match card.get_overplay(hex):
			TileCard.Overplay.MERGE:
				if not _knows("merge"):
					continue
			TileCard.Overplay.REPLACE:
				if not _knows("replace"):
					continue
		kept.append(hex)
	return kept

#endregion

#region Decisions

func choose_offer(offer: Array[TileCard], is_reward: bool) -> int:
	if _slip("pick"):
		return _rng().randi_range(0, offer.size() - 1)
	return await super.choose_offer(offer, is_reward)


func _should_reroll(best_value: float, is_reward: bool) -> bool:
	if not _knows("reroll") or not super._should_reroll(best_value, is_reward):
		return false
	return _rng().randf() < REROLL_NERVE_MIN + (1.0 - REROLL_NERVE_MIN) * _skill()


func _may_reroll_shop() -> bool:
	return _knows("reroll")


func _candidate_hexes(card: TileCard) -> Array[Hex]:
	return _filter_known(super._candidate_hexes(card), card)


func choose_hand_action(hand: Array[TileCard]) -> Dictionary:
	if _slip("place"):
		var card: TileCard = hand[_rng().randi_range(0, hand.size() - 1)]
		var hexes := _filter_known(runner.legal_hexes(card), card)
		if hexes.is_empty() or _rng().randf() < 0.15:
			return {"card": card, "sell": true}
		return {"card": card, "hex": hexes[_rng().randi_range(0, hexes.size() - 1)]}
	return await super.choose_hand_action(hand)


func before_resolve() -> void:
	if not _knows("condiments") or _slip("drink"):
		return
	await super.before_resolve()


func on_day_started() -> void:
	if not _knows("staff"):
		return
	await super.on_day_started()


func shop(visit: RefCounted) -> void:
	if _slip("shop", 0.5):
		return
	if _slip("impulse"):
		var affordable: Array[int] = []
		for index in visit.cards.size():
			var card: TileCard = visit.cards[index]
			if card != null and EconomyManager.can_afford(visit.price_of(card)):
				affordable.append(index)
		if not affordable.is_empty():
			visit.buy_card(affordable[_rng().randi_range(0, affordable.size() - 1)])
	await super.shop(visit)


func choose_station_perk(segment_index: int) -> int:
	var options := StationManager.get_choice_options(segment_index)
	# A what-if Hour asks too. It gets the careful answer, so only the real pick can slip.
	if options.size() > 1 and not runner.sim.is_simulating and _slip("perk", 1.5):
		return _rng().randi_range(0, options.size() - 1)
	return super.choose_station_perk(segment_index)

#endregion
