extends Node

## The run's deck: draw pile, hand, discard pile and played pile.
##
## Each chef starts with every Ingredient and Kitchenware plus their kit Meals
## (ChefRegistry.build_starting_deck). Every
## Hour draws HOUR_DRAW cards. Playing a card puts it on the board and its deck card on the played
## pile. The Hour ends after PLAYS_PER_HOUR plays or when the player ends it, and the cards left in
## the hand are discarded. Each new Day shuffles every pile back into the draw pile, so a card on the
## board comes back to the deck the next Day. When the draw pile runs out partway through a draw, the
## discard pile is shuffled in.
##
## Deck cards are their own TileCard instances. The board copies a card when it is placed
## (Hex.place_tile_card), so the board card and the deck card are separate once played.
##
## The Hand scene shows this hand and the playtest bot plays from it. All numbers are untuned.

## A card joined the hand (draw or debug add).
signal cards_drawn(cards: Array[TileCard])
## The hand was emptied into the discard pile at the end of an Hour.
signal hand_discarded
## Any pile changed size. The deck counters listen to this.
signal piles_changed

const HOUR_DRAW := 5
const PLAYS_PER_HOUR := 3
## Hand discards per Day (reset each Day). One discard throws away the whole hand and draws as many
## new cards. It does not use a play. Untuned.
const HAND_DISCARDS_PER_DAY := 4
## The removal service can't take the deck below this. A Day can play 12 cards, and a draw with
## both piles empty comes up short rather than failing. Untuned.
const MIN_DECK_SIZE := 10

## Where a card that joins the deck goes.
enum Destination {
	## Next card drawn. Several cards waiting for the top are drawn latest first.
	TOP,
	## A random spot in the draw pile.
	SHUFFLE,
	DISCARD,
	## Straight into the hand. Debug tools only.
	HAND,
}

## Why a card joined the deck. The source decides the pile (destination_for).
enum Source {
	PICK,
	MERCHANT,
	PACK,
	## Duplicate Order.
	COPY,
	## Send Back.
	SEND_BACK,
	DEBUG,
}

## Index 0 is the top of the pile.
var draw_pile: Array[TileCard] = []
var hand: Array[TileCard] = []
var discard_pile: Array[TileCard] = []
var played_pile: Array[TileCard] = []
## Cards waiting to go on top of the draw pile at the next draw, after any Day reshuffle.
## Latest first, so the card picked last is drawn first.
var _top_queue: Array[TileCard] = []
var plays_this_hour := 0
## Hand discards left this Day (discard_hand).
var discards_left := HAND_DISCARDS_PER_DAY
## True while discard_hand redraws, so the Hand flings the old cards instead of dropping them.
var is_redrawing := false
## Station kit ids the starting deck was built from (shown for random kitchens).
var kitchen_station_ids: Array[String] = []
## Each shuffle or random insert uses its own keyed RNG, so saves and what-ifs replay the same.
var _rng_ops := 0
var _day_reshuffle_pending := false
## False until a run's deck is dealt. Turn signals before that draw nothing.
var _run_active := false
## Removal service uses this visit. The price climbs within a visit and resets on the next.
var removals_this_visit := 0

const REMOVAL_BASE_PRICE := 3
const REMOVAL_PRICE_STEP := 1


func _ready() -> void:
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.merchant_closed.connect(_on_merchant_closed)


#region Run flow

func reset_for_new_run() -> void:
	draw_pile.clear()
	hand.clear()
	discard_pile.clear()
	played_pile.clear()
	_top_queue.clear()
	kitchen_station_ids.clear()
	plays_this_hour = 0
	discards_left = discards_per_day()
	_rng_ops = 0
	_day_reshuffle_pending = false
	_run_active = false
	removals_this_visit = 0
	piles_changed.emit()


## Deals a new run: shuffles the starting deck into the draw pile and draws the first hand.
func start_run(cards: Array[TileCard], station_ids: Array[String] = []) -> void:
	reset_for_new_run()
	kitchen_station_ids = station_ids.duplicate()
	for card: TileCard in cards:
		if card != null:
			draw_pile.append(card)
	_shuffle(draw_pile)
	_run_active = true
	begin_hour()


## Hand discards each Day: HAND_DISCARDS_PER_DAY less the difficulty's cut (Level 3 and up).
func discards_per_day() -> int:
	return maxi(0, HAND_DISCARDS_PER_DAY - Difficulty.get_hand_discard_reduction(GameManager.selected_difficulty))


## The new Day's first draw reshuffles every pile (RoundFlow calls this as the Day starts).
func start_day() -> void:
	_day_reshuffle_pending = true
	discards_left = discards_per_day()
	piles_changed.emit()


## Draws the Hour's hand.
func begin_hour() -> void:
	if not _run_active:
		return
	plays_this_hour = 0
	if _day_reshuffle_pending:
		_reshuffle_for_day()
	_apply_top_queue()
	var drawn: Array[TileCard] = []
	for _i in HOUR_DRAW:
		var card := _draw_one()
		if card == null:
			break
		hand.append(card)
		drawn.append(card)
	piles_changed.emit()
	if not drawn.is_empty():
		cards_drawn.emit(drawn)


## Moves the hand to the discard pile. Runs when the Hour ends.
func end_hour() -> void:
	plays_this_hour = 0
	if hand.is_empty():
		return
	discard_pile.append_array(hand)
	hand.clear()
	piles_changed.emit()
	hand_discarded.emit()


## A hand card was played onto the board. Its deck card waits on the played pile until the Day ends.
func play(card: TileCard) -> void:
	var index := hand.find(card)
	if index < 0:
		push_warning("DeckManager: played a card that is not in the hand.")
		return
	hand.remove_at(index)
	played_pile.append(card)
	plays_this_hour += 1
	piles_changed.emit()


## True once the Hour's plays are used up or the hand is empty.
func is_hour_finished() -> bool:
	return plays_this_hour >= PLAYS_PER_HOUR or hand.is_empty()


func plays_left() -> int:
	return maxi(0, PLAYS_PER_HOUR - plays_this_hour)


## True when a discard is left this Day and there is a hand to throw away.
func can_discard_hand() -> bool:
	return _run_active and discards_left > 0 and not hand.is_empty()


## Throws the whole hand on the discard pile and draws as many new cards (the draw pile reshuffles
## the discard pile in when it runs out, so the new hand can hold cards just thrown away). Uses one
## of the Day's discards, not a play. Returns false when no discard is left.
func discard_hand() -> bool:
	if not can_discard_hand():
		return false
	discards_left -= 1
	var count := hand.size()
	discard_pile.append_array(hand)
	hand.clear()
	is_redrawing = true
	hand_discarded.emit()
	var drawn: Array[TileCard] = []
	for _i in count:
		var card := _draw_one()
		if card == null:
			break
		hand.append(card)
		drawn.append(card)
	piles_changed.emit()
	if not drawn.is_empty():
		cards_drawn.emit(drawn)
	is_redrawing = false
	return true


func _on_turn_ended() -> void:
	end_hour()


func _on_turn_started() -> void:
	begin_hour()


func _on_merchant_closed() -> void:
	removals_this_visit = 0

#endregion

#region Gaining and removing cards

static func destination_for(source: Source) -> Destination:
	match source:
		Source.PICK:
			return Destination.TOP
		Source.SEND_BACK:
			return Destination.DISCARD
		Source.DEBUG:
			return Destination.HAND
	return Destination.SHUFFLE


## Adds a copy of card to the deck. The pile follows from source. Returns the deck copy.
## Pool cards are shared templates, so the deck always keeps its own instance.
func gain_card(card: TileCard, source: Source) -> TileCard:
	if card == null:
		return null
	var copy := make_deck_card(card)
	match destination_for(source):
		Destination.TOP:
			_top_queue.push_front(copy)
		Destination.SHUFFLE:
			_insert_shuffled(copy)
		Destination.DISCARD:
			discard_pile.append(copy)
		Destination.HAND:
			hand.append(copy)
			var drawn: Array[TileCard] = [copy]
			cards_drawn.emit(drawn)
	piles_changed.emit()
	CollectionStats.record_deck_card(copy)
	# Picked counts only the player's own choices, not copies, Send Back or debug cards.
	if source == Source.PICK or source == Source.MERCHANT or source == Source.PACK:
		CollectionStats.record_pick(CollectionStats.GROUP_CARD, copy.id)
	# Save and tutorial listeners treat this as "a card joined the deck".
	EventBus.tile_card_selected.emit(copy)
	return copy


## A clean deck instance of card: a fresh copy with its star level, no board state.
static func make_deck_card(card: TileCard) -> TileCard:
	var copy := card.duplicate(true) as TileCard
	copy.star_level = maxi(1, card.star_level)
	copy.activation_count = 0
	copy.is_garnished = false
	copy.is_active = true
	return copy


## Every card in the deck, whatever pile it sits in.
func all_cards() -> Array[TileCard]:
	var cards: Array[TileCard] = []
	cards.append_array(_top_queue)
	cards.append_array(draw_pile)
	cards.append_array(hand)
	cards.append_array(discard_pile)
	cards.append_array(played_pile)
	return cards


func deck_size() -> int:
	return _top_queue.size() + draw_pile.size() + hand.size() + discard_pile.size() + played_pile.size()


## The cards still to draw this Day, cards queued for the top included. Order is not meaningful.
func draw_pile_cards() -> Array[TileCard]:
	var cards: Array[TileCard] = []
	cards.append_array(_top_queue)
	cards.append_array(draw_pile)
	return cards


func draw_pile_size() -> int:
	return _top_queue.size() + draw_pile.size()


func can_remove_card() -> bool:
	return deck_size() > MIN_DECK_SIZE


func removal_price() -> int:
	return REMOVAL_BASE_PRICE + REMOVAL_PRICE_STEP * removals_this_visit


## Merchant removal service, step 1: pays for one removal. The player then picks a card or skips,
## and skipping does not refund the Gold. False when the deck is at its minimum or Gold is short.
func pay_for_removal() -> bool:
	if not can_remove_card() or not EconomyManager.can_afford(removal_price()):
		return false
	var price := removal_price()
	# Count it first, so the gold_changed refresh already shows the next price.
	removals_this_visit += 1
	EconomyManager.remove(price)
	return true


## Merchant removal service in one go: pays and destroys a deck card for good. The bots use it.
func buy_removal(card: TileCard) -> bool:
	if not all_cards().has(card) or not pay_for_removal():
		return false
	return remove_card(card)


## Destroys a deck card (takes it out of the run). Board copies are not touched.
func remove_card(card: TileCard) -> bool:
	for pile: Array[TileCard] in [_top_queue, draw_pile, hand, discard_pile, played_pile]:
		var index := pile.find(card)
		if index >= 0:
			pile.remove_at(index)
			piles_changed.emit()
			return true
	return false

#endregion

#region Piles

func _draw_one() -> TileCard:
	if draw_pile.is_empty():
		if discard_pile.is_empty():
			return null
		draw_pile.append_array(discard_pile)
		discard_pile.clear()
		_shuffle(draw_pile)
	return draw_pile.pop_front()


func _reshuffle_for_day() -> void:
	_day_reshuffle_pending = false
	draw_pile.append_array(hand)
	draw_pile.append_array(discard_pile)
	draw_pile.append_array(played_pile)
	hand.clear()
	discard_pile.clear()
	played_pile.clear()
	_shuffle(draw_pile)


func _apply_top_queue() -> void:
	if _top_queue.is_empty():
		return
	var queued := _top_queue.duplicate()
	_top_queue.clear()
	# Latest first, so it ends up on the very top.
	queued.reverse()
	for card: TileCard in queued:
		draw_pile.push_front(card)


func _insert_shuffled(card: TileCard) -> void:
	var rng := _next_rng()
	draw_pile.insert(rng.randi_range(0, draw_pile.size()), card)


func _shuffle(pile: Array[TileCard]) -> void:
	RunRng.shuffle_with(_next_rng(), pile)


func _next_rng() -> RandomNumberGenerator:
	_rng_ops += 1
	return RunRng.create_rng("deck:%d" % _rng_ops)

#endregion

#region Save / load and what-if snapshots

func capture_run_state() -> Dictionary:
	return {
		"top_queue": _ids_of(_top_queue),
		"draw": _ids_of(draw_pile),
		"hand": _ids_of(hand),
		"discard": _ids_of(discard_pile),
		"played": _ids_of(played_pile),
		"plays_this_hour": plays_this_hour,
		"rng_ops": _rng_ops,
		"day_reshuffle_pending": _day_reshuffle_pending,
		"discards_left": discards_left,
		"kitchen": kitchen_station_ids.duplicate(),
		"removals_this_visit": removals_this_visit,
		"run_active": _run_active,
	}


func apply_run_state(state: Dictionary) -> void:
	_top_queue = _cards_of(state.get("top_queue", []))
	draw_pile = _cards_of(state.get("draw", []))
	hand = _cards_of(state.get("hand", []))
	discard_pile = _cards_of(state.get("discard", []))
	played_pile = _cards_of(state.get("played", []))
	plays_this_hour = int(state.get("plays_this_hour", 0))
	_rng_ops = int(state.get("rng_ops", 0))
	_day_reshuffle_pending = bool(state.get("day_reshuffle_pending", false))
	discards_left = int(state.get("discards_left", discards_per_day()))
	kitchen_station_ids.assign(state.get("kitchen", []))
	# Saves from when every Hour had a card pick: the Hour's draw waited for that pick. Draw it now.
	if bool(state.get("draw_pending", false)) and hand.is_empty():
		begin_hour.call_deferred()
	removals_this_visit = int(state.get("removals_this_visit", 0))
	_run_active = bool(state.get("run_active", not state.is_empty()))
	piles_changed.emit()


## Shallow copy of every pile for the playtest bot's what-ifs. Cards are not copied.
func capture_snapshot() -> Dictionary:
	return {
		"top_queue": _top_queue.duplicate(),
		"draw": draw_pile.duplicate(),
		"hand": hand.duplicate(),
		"discard": discard_pile.duplicate(),
		"played": played_pile.duplicate(),
		"plays_this_hour": plays_this_hour,
		"rng_ops": _rng_ops,
		"day_reshuffle_pending": _day_reshuffle_pending,
		"removals_this_visit": removals_this_visit,
	}


func restore_snapshot(state: Dictionary) -> void:
	_top_queue.assign(state["top_queue"])
	draw_pile.assign(state["draw"])
	hand.assign(state["hand"])
	discard_pile.assign(state["discard"])
	played_pile.assign(state["played"])
	plays_this_hour = int(state["plays_this_hour"])
	_rng_ops = int(state["rng_ops"])
	_day_reshuffle_pending = bool(state["day_reshuffle_pending"])
	removals_this_visit = int(state["removals_this_visit"])
	piles_changed.emit()


static func _ids_of(cards: Array[TileCard]) -> Array:
	var entries: Array = []
	for card: TileCard in cards:
		if card.star_level > 1:
			entries.append({"id": String(card.id), "stars": card.star_level})
		else:
			entries.append(String(card.id))
	return entries


static func _cards_of(entries: Array) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	for entry: Variant in entries:
		var card_id := ""
		var stars := 1
		if entry is Dictionary:
			card_id = String((entry as Dictionary).get("id", ""))
			stars = int((entry as Dictionary).get("stars", 1))
		else:
			card_id = String(entry)
		var template := GameManager.get_tile_card_by_id(card_id)
		if template == null:
			push_warning("DeckManager: saved deck card '%s' is not in the pool." % card_id)
			continue
		var card := make_deck_card(template)
		card.star_level = maxi(1, stars)
		cards.append(card)
	return cards

#endregion
