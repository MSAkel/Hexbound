extends Node

## The run's deck: draw pile, hand, discard pile and played pile.
##
## Each chef starts with a deck built from Station kits (ChefRegistry.build_starting_deck). Every
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

const HOUR_DRAW := 4
const PLAYS_PER_HOUR := 2
## The removal service can't take the deck below this, so a Day never runs out of cards.
## A 4-Hour Day plays 6 cards before its last Hour, and that Hour still draws 4.
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
## Station kit ids the starting deck was built from (shown for random kitchens).
var kitchen_station_ids: Array[String] = []
## Each shuffle or random insert uses its own keyed RNG, so saves and what-ifs replay the same.
var _rng_ops := 0
var _day_reshuffle_pending := false
## A card pick is open. The Hour's draw waits for it, so the picked card is in the new hand.
var _draw_held := false
var _draw_pending := false
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
	_rng_ops = 0
	_day_reshuffle_pending = false
	_draw_held = false
	_draw_pending = false
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


## The new Day's first draw reshuffles every pile (RoundFlow calls this as the Day starts).
func start_day() -> void:
	_day_reshuffle_pending = true


## Draws the Hour's hand. A held draw (a card pick is open) waits for release_draw().
func begin_hour() -> void:
	if not _run_active:
		return
	if _draw_held:
		_draw_pending = true
		return
	_draw_pending = false
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


## Holds the next Hour's draw while a card pick is open.
func hold_draw() -> void:
	if _run_active:
		_draw_held = true


## Ends a hold. Draws now if the Hour already started.
func release_draw() -> void:
	_draw_held = false
	if _draw_pending:
		begin_hour()


func is_draw_pending() -> bool:
	return _draw_held or _draw_pending


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


func draw_pile_size() -> int:
	return _top_queue.size() + draw_pile.size()


func can_remove_card() -> bool:
	return deck_size() > MIN_DECK_SIZE


func removal_price() -> int:
	return REMOVAL_BASE_PRICE + REMOVAL_PRICE_STEP * removals_this_visit


## Merchant removal service: pays and destroys a deck card for good. False when it can't.
func buy_removal(card: TileCard) -> bool:
	if not can_remove_card() or not EconomyManager.can_afford(removal_price()):
		return false
	var price := removal_price()
	if not remove_card(card):
		return false
	EconomyManager.remove(price)
	removals_this_visit += 1
	return true


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
		"draw_pending": _draw_held or _draw_pending,
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
	# A pick that was open when the run was saved reopens and holds the draw again.
	_draw_pending = bool(state.get("draw_pending", false))
	_draw_held = _draw_pending
	kitchen_station_ids.assign(state.get("kitchen", []))
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
		"draw_held": _draw_held,
		"draw_pending": _draw_pending,
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
	_draw_held = bool(state["draw_held"])
	_draw_pending = bool(state["draw_pending"])
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
