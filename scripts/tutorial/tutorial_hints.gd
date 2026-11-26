class_name TutorialHints
extends RefCounted

## Every tutorial hint: copy, where it points, and when it may appear.
## Ids are saved in the player's tutorial progress, so never rename a shipped id.
##
## Body text uses glossary tokens ({flavour}, {mult}, ...) and **double asterisks** for highlights.

const _CondimentManagerScript := preload("res://scripts/autoload/condiment_manager.gd")
const _StationManagerScript := preload("res://scripts/autoload/station_manager.gd")
## Example type for the basics. Its requirements are read from it so the copy stays true.

## Which screen must be up before the hint can show. Hints wait in the queue until it is.
enum Context {
	## Board idle: hand up, no panel open, nothing resolving or being dragged.
	HOUR,
	CARD_PICK,
	MERCHANT,
	STATION_CHOICE,
	## Whichever of HOUR, CARD_PICK or MERCHANT is up. For hints about a card that can turn up anywhere.
	ANY_CARD_SCREEN,
}

const CATEGORY_BASICS := "Basics"
const CATEGORY_CARDS := "Cards"
const CATEGORY_MERCHANT := "Merchant"
const CATEGORY_KITCHEN := "Stations"
const CATEGORY_EVENTS := "Events"
## Archive order.
const CATEGORIES: Array[String] = [
	CATEGORY_BASICS,
	CATEGORY_CARDS,
	CATEGORY_MERCHANT,
	CATEGORY_KITCHEN,
	CATEGORY_EVENTS,
]

const PRIORITY_CHAIN := 100
const PRIORITY_URGENT := 90
const PRIORITY_PANEL := 80
const PRIORITY_NORMAL := 50
const PRIORITY_LOW := 30

const HIGHLIGHT_COLOR := Color("#ffd166")
## Lighter than the card glossary green so keywords read on the dark callout.
const KEYWORD_COLOR := Color("#6fdc9c")

## Multi-step sequences. Requesting the chain id queues its first unseen step.
const CHAINS := {
	&"basics": [
		&"basics_welcome",
		&"basics_hand",
		&"basics_place",
		&"basics_stations",
		&"basics_station_types",
		&"basics_score",
		&"basics_hour_end",
	],
	&"merchant": [
		&"merchant_intro",
		&"merchant_condiments",
		&"merchant_lock",
		&"merchant_reroll",
		&"merchant_leave",
	],
}

## Body holds a %d for the free rerolls per Day, filled in by TutorialManager.get_body. The card
## pick tips (this one and "New card") were removed with the end-of-Day card pick, so no tip has
## this id now.
const REROLL_HINT := &"card_pick_reroll"

static var _defs: Dictionary = {}
static var _order: Array[StringName] = []
static var _highlight_regex: RegEx = null


static func _static_init() -> void:
	# Basics: first run, Day 1, walks through one Hour.
	_add(&"basics_welcome", CATEGORY_BASICS, "Welcome to the kitchen!",
		"Let's learn the basics.",
		Context.HOUR, [], PRIORITY_CHAIN)
	_add(&"basics_hand", CATEGORY_BASICS, "Your hand",
		"You draw **%d** cards from the **deck** each Turn. **%ss** make {flavour}. **%s** boosts the %ss." % [
			DeckManager.HOUR_DRAW, GameTerms.INGREDIENT, GameTerms.KITCHENWARE, GameTerms.INGREDIENT,
		],
		Context.HOUR, [&"hand", &"deck_pile"], PRIORITY_CHAIN)
	_add(&"basics_place", CATEGORY_BASICS, "Place a card",
		"Drag an %s card onto an empty **spot**." % GameTerms.INGREDIENT.to_lower(),
		Context.HOUR, [&"board_spot", &"hand"], PRIORITY_CHAIN, &"card_played")
	_add(&"basics_stations", CATEGORY_BASICS, "Stations",
		"Each row is a **Station**. **6 spots** for %ss and %s, then **2 spots** for **%ss**. Stations trigger top to bottom." % [
			GameTerms.INGREDIENT, GameTerms.KITCHENWARE, GameTerms.MEAL,
		],
		Context.HOUR, [&"board_station"], PRIORITY_CHAIN)
	_add(&"basics_station_types", CATEGORY_BASICS, "Station types",
		_station_types_body(),
		Context.HOUR, [&"board_station"], PRIORITY_CHAIN)
	_add(&"basics_score", CATEGORY_BASICS, "Turn Rating",
		"Cards add {flavour} and {mult}. At the end of the Turn, **{flavour} × {mult}** is its **%s**." % GameTerms.RATING,
		Context.HOUR, [&"hand"], PRIORITY_CHAIN)
	_add(&"basics_hour_end", CATEGORY_BASICS, "Ending the Turn",
		"You can play **%d cards** each Turn. Cards left in your hand go to the **discard pile**. Each new Day shuffles every card, even the ones you played, back into your deck." % DeckManager.PLAYS_PER_HOUR,
		Context.HOUR, [&"hand"], PRIORITY_CHAIN)

	# Cards.
	_add(&"overplay", CATEGORY_CARDS, "Star up",
		"Play a card onto **its own copy** to **star** it (+%d%% each). A different card can't go on a taken %s." % [
			roundi(TileCard.STAR_SCALE_STEP * 100.0), GameTerms.SPOT.to_lower(),
		],
		Context.HOUR, [&"hand"], PRIORITY_NORMAL)

	# Merchant.
	_add(&"merchant_intro", CATEGORY_MERCHANT, "The Merchant",
		"Spend **%s** on cards and **%s** between Days. Bought cards shuffle into your deck." % [GameTerms.GOLD, GameTerms.TECHNIQUES],
		Context.MERCHANT, [&"merchant_cards"], PRIORITY_PANEL)
	_add(&"merchant_condiments", CATEGORY_MERCHANT, GameTerms.CONDIMENTS,
		"**%s** are one-use boosts. Carry up to **%d**." % [
			GameTerms.CONDIMENTS, _CondimentManagerScript.BELT_SIZE,
		],
		Context.MERCHANT, [&"merchant_condiments"], PRIORITY_PANEL)
	_add(&"merchant_lock", CATEGORY_MERCHANT, "Locking",
		"**Lock** an item to keep it for your next visit.",
		Context.MERCHANT, [&"merchant_cards"], PRIORITY_PANEL)
	_add(&"merchant_reroll", CATEGORY_MERCHANT, "Restock",
		"**Reroll** the shelf for %s." % GameTerms.GOLD,
		Context.MERCHANT, [&"merchant_reroll"], PRIORITY_PANEL)
	_add(&"merchant_leave", CATEGORY_MERCHANT, "Next Day",
		"Leave to start the next Day.",
		Context.MERCHANT, [&"merchant_leave"], PRIORITY_PANEL)
	_add(&"staff", CATEGORY_MERCHANT, GameTerms.TECHNIQUES,
		"**%s** sit beside a Station. Drag a %s to swap Stations. Click one to **sell** it." % [
			GameTerms.TECHNIQUES, GameTerms.TECHNIQUE,
		],
		Context.HOUR, [&"staff_slot"], PRIORITY_NORMAL)
	_add(&"condiments", CATEGORY_MERCHANT, "Using %s" % GameTerms.CONDIMENTS,
		"**Drag** a Condiment out to use it. Some need a target. Click one to **sell** it.",
		Context.HOUR, [&"condiment_belt"], PRIORITY_NORMAL)

	# Stations.
	_add(&"station_type", CATEGORY_KITCHEN, "Station type",
		"This Station has a **type** now. Lose the cards it needs and it loses the type and its level.",
		Context.HOUR, [&"typed_station"], PRIORITY_NORMAL)
	_add(&"station_level", CATEGORY_KITCHEN, "Station level",
		"Serving **%ss** levels up a Station. At levels **%d** and **%d** you choose a **perk**." % [
			GameTerms.MEAL, _StationManagerScript.CHOICE_LEVEL, _StationManagerScript.CAPSTONE_LEVEL,
		],
		Context.HOUR, [&"leveled_station"], PRIORITY_NORMAL)
	_add(&"station_perk", CATEGORY_KITCHEN, "Station perk",
		"Pick a **perk** for this Station. At level %d, a locked **%s** opens too." % [
			_StationManagerScript.CHOICE_LEVEL, GameTerms.MEAL_SLOT,
		],
		Context.STATION_CHOICE, [], PRIORITY_PANEL)

	# Events.
	_add(&"event_preview", CATEGORY_EVENTS, "Events",
		"Some Days bring an **event** that changes the rules. Hover here to preview the next one.",
		Context.HOUR, [&"event_icon"], PRIORITY_NORMAL)
	_add(&"event_active", CATEGORY_EVENTS, "Event active",
		"Today's **event** lasts until the Day ends. Hover to check it.",
		Context.HOUR, [&"event_icon"], PRIORITY_URGENT)


static func _station_types_body() -> String:
	return "The right cards on a Station's 6 spots give it a **type** and a bonus. You can view all station types in the **Collection**."


static func _add(
	id: StringName,
	category: String,
	title: String,
	body: String,
	context: Context,
	anchors: Array[StringName],
	priority: int,
	action_signal: StringName = &""
) -> void:
	_defs[id] = {
		"id": id,
		"category": category,
		"title": title,
		"body": body,
		"context": context,
		"anchors": anchors,
		"priority": priority,
		## Empty: click to continue. Otherwise the EventBus signal that completes the step.
		"action_signal": action_signal,
	}
	_order.append(id)


static func has(id: StringName) -> bool:
	return _defs.has(id)


static func get_def(id: StringName) -> Dictionary:
	return _defs.get(id, {})


static func all_ids() -> Array[StringName]:
	return _order


static func chain_of(id: StringName) -> StringName:
	for chain_id: StringName in CHAINS:
		if id in CHAINS[chain_id]:
			return chain_id
	return &""


static func chain_steps(chain_id: StringName) -> Array:
	return CHAINS.get(chain_id, [])


## Keyword tokens and **highlights** become RichTextLabel markup.
static func to_bbcode(text: String) -> String:
	if _highlight_regex == null:
		_highlight_regex = RegEx.create_from_string("\\*\\*(.+?)\\*\\*")
	var bbcode := CardKeywordGlossary.to_bbcode(text, KEYWORD_COLOR)
	return _highlight_regex.sub(bbcode, "[color=#%s]$1[/color]" % HIGHLIGHT_COLOR.to_html(false), true)


## Plain text for places without BBCode.
static func to_plain(text: String) -> String:
	return CardKeywordGlossary.to_plain(text).replace("**", "")
