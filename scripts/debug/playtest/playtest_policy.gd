extends RefCounted

## Decisions for one playtest bot. The runner owns the real day flow and calls these at the
## same points a player decides. Every method may await. Defaults do the least a player can.

## Bot id written to the report.
var id := "base"
## PlaytestRunner driving the run. Exposes map, sim, hand, legal_hexes(), and the action helpers.
var runner: Node


func on_run_started() -> void:
	pass


## Start of a day, before the first Hour. Staff can be rearranged here.
func on_day_started() -> void:
	pass


## Index of the card to take, or -1 to spend a reroll.
func choose_offer(_offer: Array[TileCard], _is_reward: bool) -> int:
	return 0


## {"card": TileCard, "hex": Hex} to play, or {"card": TileCard, "sell": true}.
func choose_hand_action(hand: Array[TileCard]) -> Dictionary:
	for card: TileCard in hand:
		var hexes: Array[Hex] = runner.legal_hexes(card)
		if not hexes.is_empty():
			return {"card": card, "hex": hexes[0]}
	return {"card": hand[0], "sell": true}


## Belt drinks before the Hour resolves. Call runner.drink_condiment().
func before_resolve() -> void:
	pass


## One merchant visit. visit is a PlaytestRunner.MerchantVisit.
func shop(_visit: RefCounted) -> void:
	pass


## Level 3 station pick. Called mid-Hour, so it must not await.
func choose_station_perk(_segment_index: int) -> int:
	return 0
