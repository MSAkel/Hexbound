extends Node

## Headless check of the deck rules on the real run screen (Hand, card picks, Merchant, RoundFlow,
## saves), which the playtest bot skips. Fails on a broken rule or a script error.
##
## godot --headless --path . res://scenes/debug/deck_flow_check.tscn
##
## Plays Pitmaster on a fixed seed: draws 4, plays 2 (the Hour ends), picks a card (it is drawn
## next Hour), ends an Hour early with End Hour and skips the pick, saves, then finishes the Day,
## picks again, uses the removal service, checks the new Day reshuffled every pile, and continues
## the saved run to check the deck comes back the same.

const CHEF_ID := "pitmaster"
const WAIT_LIMIT := 60.0

var _failures: Array[String] = []
var _main: Node = null


func _ready() -> void:
	TutorialManager.hints_enabled = false
	RunSaveManager.delete_save()
	GameManager.selected_chef = ChefRegistry.get_chef_by_id(CHEF_ID)
	RunRng.begin_new_run("DECKFLOW")
	_main = (load(ScenePaths.MAIN) as PackedScene).instantiate()
	get_tree().root.add_child.call_deferred(_main)
	await get_tree().create_timer(1.0).timeout
	await _run()
	RunSaveManager.delete_save()
	if _failures.is_empty():
		print("[deck_flow] PASS")
	else:
		for failure in _failures:
			print("[deck_flow] FAIL %s" % failure)
	get_tree().quit(0 if _failures.is_empty() else 1)


func _run() -> void:
	var hand := get_tree().get_first_node_in_group("run_hand") as Hand
	var selection := get_tree().get_first_node_in_group("run_card_selection") as CardSelectionUI
	if hand == null or selection == null:
		_fail("run screen did not load")
		return
	await _wait_until(func() -> bool: return not hand.is_hand_hidden(), "the opening hand to show")

	_check(DeckManager.deck_size() == ChefRegistry.get_expected_deck_size(GameManager.selected_chef),
		"starting deck has %d cards" % DeckManager.deck_size())
	_check(DeckManager.hand.size() == DeckManager.HOUR_DRAW, "opening hand holds %d cards" % DeckManager.hand.size())
	_check(_hand_ui_count(hand) == DeckManager.HOUR_DRAW, "opening hand shows %d cards" % _hand_ui_count(hand))

	# Hour 1: two plays end the Hour, then the pick is drawn next Hour.
	for _play in DeckManager.PLAYS_PER_HOUR:
		if not await _play_one(hand):
			return
	await _wait_until(func() -> bool: return selection.visible, "the Hour 1 card pick")
	_check(DeckManager.hand.is_empty(), "hand discarded after the Hour")
	_check(DeckManager.is_draw_pending(), "the next Hour's draw waits for the pick")
	_check(DeckManager.played_pile.size() == DeckManager.PLAYS_PER_HOUR, "played pile holds the Hour's plays")
	var choice := selection._first_choice_card()
	if choice == null:
		_fail("card pick showed no cards")
		return
	var picked_id := String(choice.card.id)
	selection._on_tile_card_choice_selected(choice)
	await _wait_until(func() -> bool: return not hand.is_hand_hidden(), "the Hour 2 hand to show")
	_check(DeckManager.hand.size() == DeckManager.HOUR_DRAW, "Hour 2 hand holds %d cards" % DeckManager.hand.size())
	_check(_hand_ids().has(picked_id), "the picked card (%s) is in the next hand" % picked_id)
	_check(_hand_ui_count(hand) == DeckManager.HOUR_DRAW, "Hour 2 hand shows %d cards" % _hand_ui_count(hand))
	_check(DeckManager.deck_size() == ChefRegistry.get_expected_deck_size(GameManager.selected_chef) + 1,
		"the pick joined the deck")

	# Hour 2: End Hour with no plays, then skip the pick.
	var discard_before := DeckManager.discard_pile.size()
	_check(hand.can_end_hour(), "End Hour is available")
	hand.end_hour()
	await _wait_until(func() -> bool: return selection.visible, "the Hour 2 card pick")
	_check(DeckManager.discard_pile.size() == discard_before + DeckManager.HOUR_DRAW, "End Hour discarded the hand")
	var deck_before_skip := DeckManager.deck_size()
	selection._on_skip_button_pressed()
	await _wait_until(func() -> bool: return not hand.is_hand_hidden(), "the Hour 3 hand to show")
	_check(DeckManager.deck_size() == deck_before_skip, "skipping the pick added no card")
	_check(DeckManager.hand.size() == DeckManager.HOUR_DRAW, "Hour 3 hand holds %d cards" % DeckManager.hand.size())

	# Save, then read the deck back from the file.
	RunSaveManager.save_current_run()
	var payload: Dictionary = preload("res://scripts/helpers/atomic_save_file.gd").read_json_dictionary(RunSaveManager.SAVE_PATH)
	var saved_deck: Dictionary = payload.get("deck", {})
	_check((saved_deck.get("hand", []) as Array).size() == DeckManager.HOUR_DRAW, "the save holds the hand")
	var saved_total := 0
	for key in ["top_queue", "draw", "hand", "discard", "played"]:
		saved_total += (saved_deck.get(key, []) as Array).size()
	_check(saved_total == DeckManager.deck_size(), "the save holds every deck card (%d of %d)" % [saved_total, DeckManager.deck_size()])

	# End the Day, pick, use the removal service, start the next Day.
	GameManager.debug_meet_round_goal_and_complete()
	await _wait_until(func() -> bool: return RoundFlow.get_step() == RoundFlow.Step.SUMMARY, "the Day summary")
	RoundFlow.notify_summary_confirmed()
	await _wait_until(func() -> bool: return selection.visible, "the end-of-Day pick")
	choice = selection._first_choice_card()
	var day_pick_id := String(choice.card.id) if choice != null else ""
	selection._on_tile_card_choice_selected(choice)
	await _wait_until(func() -> bool: return RoundFlow.get_step() == RoundFlow.Step.MERCHANT, "the Merchant")
	var merchant := get_tree().get_first_node_in_group("run_merchant")
	var viewer := get_tree().get_first_node_in_group("deck_viewer") as DeckViewer
	_check(viewer != null, "the deck viewer exists")
	if viewer != null:
		viewer.open_removal()
		_check(viewer.is_open(), "the removal service opens the deck viewer")
		viewer.close()
	EconomyManager.add(10)
	var size_before_removal := DeckManager.deck_size()
	var price := DeckManager.removal_price()
	var gold_before := EconomyManager.amount
	_check(DeckManager.buy_removal(DeckManager.all_cards()[0]), "the removal service removes a card")
	_check(DeckManager.deck_size() == size_before_removal - 1, "the deck lost one card")
	_check(EconomyManager.amount == gold_before - price, "removal cost %d Gold" % price)
	_check(DeckManager.removal_price() == price + DeckManager.REMOVAL_PRICE_STEP, "a second removal costs more")
	merchant._on_leave_button_pressed()
	await _wait_until(func() -> bool: return RoundFlow.get_step() == RoundFlow.Step.IDLE and not hand.is_hand_hidden(), "Day 2 to start")
	_check(DeckManager.removal_price() == DeckManager.REMOVAL_BASE_PRICE, "removal price resets after the visit")
	_check(DeckManager.played_pile.is_empty(), "the new Day shuffled the played pile back in")
	_check(DeckManager.discard_pile.is_empty(), "the new Day shuffled the discard pile back in")
	_check(DeckManager.hand.size() == DeckManager.HOUR_DRAW, "Day 2 hand holds %d cards" % DeckManager.hand.size())
	_check(day_pick_id.is_empty() or _hand_ids().has(day_pick_id), "the end-of-Day pick (%s) is in Day 2's opening hand" % day_pick_id)

	# Save, leave, and Continue: the deck and hand must come back as they were.
	RunSaveManager.save_current_run()
	var hand_before := _hand_ids()
	var deck_before := DeckManager.deck_size()
	_main.queue_free()
	await get_tree().process_frame
	await get_tree().process_frame
	DeckManager.reset_for_new_run()
	RunSaveManager.continue_run_pending = true
	_main = (load(ScenePaths.MAIN) as PackedScene).instantiate()
	get_tree().root.add_child(_main)
	await get_tree().create_timer(1.0).timeout
	hand = get_tree().get_first_node_in_group("run_hand") as Hand
	await _wait_until(func() -> bool: return hand != null and not hand.is_hand_hidden(), "the continued run's hand to show")
	_check(DeckManager.deck_size() == deck_before, "Continue restored %d of %d deck cards" % [DeckManager.deck_size(), deck_before])
	_check(_hand_ids() == hand_before, "Continue restored the hand")
	_check(_hand_ui_count(hand) == hand_before.size(), "the continued hand shows %d cards" % _hand_ui_count(hand))


func _play_one(hand: Hand) -> bool:
	var map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	for card_ui: CardUI in _hand_cards(hand):
		var card := card_ui.card as TileCard
		for hex: Hex in map.get_hexes_in_trigger_order():
			if card.can_play_on(hex):
				card.play_on(hex, false)
				EventBus.card_played.emit(card_ui)
				card_ui.queue_free()
				await get_tree().create_timer(0.3).timeout
				return true
	_fail("no hand card had a legal spot")
	return false


func _hand_cards(hand: Hand) -> Array[CardUI]:
	var cards: Array[CardUI] = []
	for child in hand.get_children():
		if child is CardUI and not child.is_queued_for_deletion():
			cards.append(child as CardUI)
	return cards


func _hand_ui_count(hand: Hand) -> int:
	return _hand_cards(hand).size()


func _hand_ids() -> Array[String]:
	var ids: Array[String] = []
	for card: TileCard in DeckManager.hand:
		ids.append(String(card.id))
	return ids


func _wait_until(condition: Callable, what: String) -> void:
	var waited := 0.0
	while not condition.call():
		await get_tree().create_timer(0.1).timeout
		waited += 0.1
		if waited > WAIT_LIMIT:
			_fail("timed out waiting for %s (step %s, processing %s, plays %d, hand %d, held %s, paused %s)" % [
				what, RoundFlow.Step.find_key(RoundFlow.get_step()), GameManager.is_processing_turn,
				DeckManager.plays_this_hour, DeckManager.hand.size(), DeckManager.is_draw_pending(), get_tree().paused,
			])
			return


func _check(ok: bool, what: String) -> void:
	if not ok:
		_fail(what)


func _fail(what: String) -> void:
	_failures.append(what)
	print("[deck_flow]   failed: %s" % what)
