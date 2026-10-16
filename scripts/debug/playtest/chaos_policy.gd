extends "res://scripts/debug/playtest/playtest_policy.gd"

## Bug hunter. Takes random legal actions, favouring Kitchenware and Meals because their
## retriggers and recipes stress the resolver most. Every roll comes from a seeded stream.

var _step := 0


func _init() -> void:
	id = "chaos"


func on_run_started() -> void:
	_step = 0


func _rng() -> RandomNumberGenerator:
	_step += 1
	return RunRng.create_rng("chaos:%d" % _step)


func _stress_weight(card: TileCard) -> float:
	match card.type:
		TileCard.TileCardType.KITCHENWARE:
			return 70.0
		TileCard.TileCardType.MEAL:
			return 55.0
	return 12.0


func _weighted_index(cards: Array[TileCard]) -> int:
	var weights: Array[float] = []
	var total := 0.0
	for card: TileCard in cards:
		var weight := _stress_weight(card) + _rng().randf() * 8.0
		weights.append(weight)
		total += weight
	var roll := _rng().randf() * total
	for index in cards.size():
		roll -= weights[index]
		if roll <= 0.0:
			return index
	return cards.size() - 1


func choose_offer(offer: Array[TileCard], _is_reward: bool) -> int:
	if EconomyManager.can_reroll() and _rng().randf() < 0.2:
		return -1
	return _weighted_index(offer)


func choose_hand_action(hand: Array[TileCard]) -> Dictionary:
	var card: TileCard = hand[_weighted_index(hand)]
	var hexes: Array[Hex] = runner.legal_hexes(card)
	if hexes.is_empty() or _rng().randf() < 0.1:
		return {"card": card, "sell": true}
	return {"card": card, "hex": hexes[_rng().randi_range(0, hexes.size() - 1)]}


func before_resolve() -> void:
	if not runner.use_condiments:
		return
	for slot in CondimentManager.BELT_SIZE:
		var condiment: Condiment = CondimentManager.belt[slot]
		if condiment == null or _rng().randf() > 0.4:
			continue
		var occupied: Array[Hex] = []
		for hex: Hex in runner.map.get_hexes_in_trigger_order():
			if hex.active_tile_card != null:
				occupied.append(hex)
		if condiment.needs_tile_target() and occupied.is_empty():
			continue
		var a: Hex = null
		var b: Hex = null
		if condiment.needs_tile_target():
			a = occupied[_rng().randi_range(0, occupied.size() - 1)]
			b = occupied[_rng().randi_range(0, occupied.size() - 1)]
		runner.drink_condiment(slot, a, b)


func on_day_started() -> void:
	var from_slot := _rng().randi_range(0, StaffManager.SLOT_COUNT - 1)
	var to_slot := _rng().randi_range(0, StaffManager.SLOT_COUNT - 1)
	if StaffManager.get_staff(from_slot) != null and from_slot != to_slot:
		runner.move_staff(from_slot, to_slot)


func shop(visit: RefCounted) -> void:
	for _attempt in 4:
		var choice := _rng().randi_range(0, 2)
		match choice:
			0:
				var index := _rng().randi_range(0, visit.cards.size() - 1)
				if visit.cards[index] != null and EconomyManager.can_afford(visit.price_of(visit.cards[index])):
					visit.buy_card(index)
			1:
				if not visit.staff.is_empty() and visit.staff[0] != null:
					if not StaffManager.has_free_slot():
						runner.sell_staff(_rng().randi_range(0, StaffManager.SLOT_COUNT - 1))
					if EconomyManager.can_afford(visit.price_of(visit.staff[0])):
						visit.buy_staff(0, StaffManager.first_free_slot())
			2:
				if runner.use_condiments and CondimentManager.can_add():
					var index := _rng().randi_range(0, visit.condiments.size() - 1)
					if visit.condiments[index] != null and EconomyManager.can_afford(visit.price_of(visit.condiments[index])):
						visit.buy_condiment(index)
	if EconomyManager.can_afford(visit.reroll_cost) and _rng().randf() < 0.3:
		visit.reroll()


func choose_station_perk(segment_index: int) -> int:
	var options := StationManager.get_choice_options(segment_index)
	return _rng().randi_range(0, maxi(0, options.size() - 1))
