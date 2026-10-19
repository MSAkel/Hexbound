class_name TutorialHints
extends RefCounted

## Every tutorial hint: copy, where it points, and when it may appear.
## Ids are saved in the player's tutorial progress, so never rename a shipped id.
##
## Body text uses glossary tokens ({flavour}, {mult}, ...) and **double asterisks** for highlights.

const _GameManagerScript := preload("res://scripts/autoload/game_manager.gd")
const _EconomyManagerScript := preload("res://scripts/autoload/economy_manager.gd")
const _CondimentManagerScript := preload("res://scripts/autoload/condiment_manager.gd")
const _StationManagerScript := preload("res://scripts/autoload/station_manager.gd")
const _SellPanelScript := preload("res://scenes/ui/sell_panel/card_sell_panel.gd")
## Example type for the basics. Requirements and bonus are read from it so the copy stays true.
const EXAMPLE_STATION_PATH := "res://resources/stations/cold_station.tres"

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
const CATEGORY_DAYS := "Days & Gold"
const CATEGORY_MERCHANT := "Merchant"
const CATEGORY_KITCHEN := "Stations"
const CATEGORY_EVENTS := "Events"
## Archive order.
const CATEGORIES: Array[String] = [
	CATEGORY_BASICS,
	CATEGORY_CARDS,
	CATEGORY_DAYS,
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
		&"basics_goal",
		&"basics_hour_end",
	],
	&"card_pick": [&"card_pick_choose", &"card_pick_reroll"],
	&"merchant": [
		&"merchant_intro",
		&"merchant_condiments",
		&"merchant_lock",
		&"merchant_reroll",
		&"merchant_leave",
	],
}

## Shown with the chef's own name and speciality. Seen once per chef.
const CHEF_HINT := &"chef_speciality"

static var _defs: Dictionary = {}
static var _order: Array[StringName] = []
static var _highlight_regex: RegEx = null


static func _static_init() -> void:
	var hours: int = _GameManagerScript.MAX_TURNS_PER_ROUND
	var days: int = ScoreProgression.RUN_LENGTH_ROUNDS

	# Basics: first run, Day 1, walks through one Hour.
	_add(&"basics_welcome", CATEGORY_BASICS, "Welcome to the kitchen!",
		"Let's learn the basics. Every tip can be read again later from **Tips** in the pause menu.",
		Context.HOUR, [], PRIORITY_CHAIN)
	_add(&"basics_hand", CATEGORY_BASICS, "Your hand",
		"These are your cards. **%ss** make {flavour} or {mult}. **%s** supports the cards around it." % [
			GameTerms.INGREDIENT, GameTerms.KITCHENWARE,
		],
		Context.HOUR, [&"hand"], PRIORITY_CHAIN)
	_add(&"basics_place", CATEGORY_BASICS, "Place a card",
		"Drag a card from your hand onto an empty **spot**, like this one.",
		Context.HOUR, [&"board_spot", &"hand"], PRIORITY_CHAIN, &"card_played")
	_add(&"basics_stations", CATEGORY_BASICS, "Stations",
		"Each row is a **Station**. Its first **6 spots** hold **%ss** and **%s**. The last **2** are **%ss** for **%ss**. Each Hour, cards trigger Station by Station." % [
			GameTerms.INGREDIENT, GameTerms.KITCHENWARE, GameTerms.MEAL_SLOT, GameTerms.MEAL,
		],
		Context.HOUR, [&"board_station"], PRIORITY_CHAIN)
	_add(&"basics_station_types", CATEGORY_BASICS, "Station types",
		_station_types_body(),
		Context.HOUR, [&"board_station"], PRIORITY_CHAIN)
	_add(&"basics_score", CATEGORY_BASICS, "Hour Rating",
		"Each card shows what it adds: {flavour} or {mult}. When the Hour ends, the whole kitchen's **{flavour} × {mult}** becomes the Hour's **%s**." % GameTerms.RATING,
		Context.HOUR, [&"hand"], PRIORITY_CHAIN)
	_add(&"basics_goal", CATEGORY_BASICS, "The Day's target",
		"Every Hour's Rating adds to the Day. Reach the **target** within **%d Hours** to finish the Day. Run out of Hours first and the **run ends**. Survive **%d Days** to win." % [hours, days],
		Context.HOUR, [&"day_score", &"hours_left"], PRIORITY_CHAIN)
	_add(&"basics_hour_end", CATEGORY_BASICS, "Ending the Hour",
		"There is no end-turn button. The Hour ends on its own when only **2 cards** are left in your hand.",
		Context.HOUR, [&"hand"], PRIORITY_CHAIN)

	# Cards.
	_add(&"card_pick_choose", CATEGORY_CARDS, "New card",
		"After each Hour, pick **1 of 3** cards to add to your hand.",
		Context.CARD_PICK, [&"card_choices"], PRIORITY_PANEL)
	_add(&"card_pick_reroll", CATEGORY_CARDS, "Free rerolls",
		"Not what you need? **Reroll** the choices. You get **%d free rerolls** every Day." % _EconomyManagerScript.STARTING_REROLLS,
		Context.CARD_PICK, [&"card_reroll"], PRIORITY_PANEL)
	_add(&"overplay", CATEGORY_CARDS, "Star up and replace",
		"Play a card onto a **copy of itself** to **Star it up** and make it stronger. Playing a different card on a taken spot **replaces** the card there.",
		Context.HOUR, [&"hand"], PRIORITY_NORMAL)
	_add(&"keywords", CATEGORY_CARDS, "Keywords",
		"Coloured words like {garnish} and {trigger} are **keywords**. Hover a card to see what they mean.",
		Context.HOUR, [&"hand"], PRIORITY_LOW)
	_add(&"meal_cards", CATEGORY_CARDS, "%ss" % GameTerms.MEAL,
		"This is a **%s**. %ss only go in **%ss**, the last 2 spots of a Station. Its **recipe** must be on that Station's spots, or it fails. A served Meal pays **%s** and counts toward its Station's level." % [
			GameTerms.MEAL, GameTerms.MEAL, GameTerms.MEAL_SLOT, GameTerms.GOLD,
		],
		Context.ANY_CARD_SCREEN, [&"meal_card", &"meal_slot"], PRIORITY_NORMAL)
	_add(&"sell", CATEGORY_CARDS, "Selling",
		"Don't need a card? Drag it here to **sell** it for **%d %s**. Staff and %s can be sold here too. A sold card leaves your hand, so it can end the Hour." % [
			_SellPanelScript.SELL_VALUE, GameTerms.GOLD, GameTerms.CONDIMENTS,
		],
		Context.HOUR, [&"sell_panel"], PRIORITY_LOW)

	# Days and Gold.
	_add(CHEF_HINT, CATEGORY_DAYS, "Chef speciality",
		"Each chef has a **speciality** that lasts the whole run. Build around it!",
		Context.HOUR, [], PRIORITY_LOW)

	# Merchant.
	_add(&"merchant_intro", CATEGORY_MERCHANT, "The Merchant",
		"Between Days, spend **%s** on new cards and **Staff**. Bought cards go to your hand." % GameTerms.GOLD,
		Context.MERCHANT, [&"merchant_cards"], PRIORITY_PANEL)
	_add(&"merchant_condiments", CATEGORY_MERCHANT, GameTerms.CONDIMENTS,
		"**%s** are one-use boosts. You can carry **%d** at a time." % [
			GameTerms.CONDIMENTS, _CondimentManagerScript.BELT_SIZE,
		],
		Context.MERCHANT, [&"merchant_condiments"], PRIORITY_PANEL)
	_add(&"merchant_lock", CATEGORY_MERCHANT, "Locking",
		"Use the **lock** on an item to keep it on the shelf for your next visit.",
		Context.MERCHANT, [&"merchant_cards"], PRIORITY_PANEL)
	_add(&"merchant_reroll", CATEGORY_MERCHANT, "Restock",
		"**Reroll** the shelf for %s. The price goes up each time you reroll." % GameTerms.GOLD,
		Context.MERCHANT, [&"merchant_reroll"], PRIORITY_PANEL)
	_add(&"merchant_leave", CATEGORY_MERCHANT, "Next Day",
		"Leave when you're ready to start the next Day.",
		Context.MERCHANT, [&"merchant_leave"], PRIORITY_PANEL)
	_add(&"staff", CATEGORY_MERCHANT, "Staff",
		"**Staff** work beside a Station. Each one has its own condition for when it helps, so hover a Staff to see what it does. Drag Staff to swap Stations, or onto the sell spot to sell them.",
		Context.HOUR, [&"staff_slot"], PRIORITY_NORMAL)
	_add(&"condiments", CATEGORY_MERCHANT, "Using %s" % GameTerms.CONDIMENTS,
		"Your **%s** wait here. **Drag** one out to use it. Some need a target spot. Drag one onto the sell spot to **sell** it." % GameTerms.CONDIMENTS,
		Context.HOUR, [&"condiment_belt"], PRIORITY_NORMAL)

	# Stations.
	_add(&"station_type", CATEGORY_KITCHEN, "Station type",
		"This Station now has a **type**, set by the cards on it. It keeps the type as long as its cards still meet the requirements.",
		Context.HOUR, [&"typed_station"], PRIORITY_NORMAL)
	_add(&"station_level", CATEGORY_KITCHEN, "Station level",
		"Serving **%ss** levels up a Station. At **level %d** it opens a second **%s** and lets you choose a perk." % [
			GameTerms.MEAL, _StationManagerScript.CHOICE_LEVEL, GameTerms.MEAL_SLOT,
		],
		Context.HOUR, [&"leveled_station"], PRIORITY_NORMAL)
	_add(&"station_perk", CATEGORY_KITCHEN, "Station perk",
		"Level %d! Choose a **perk** for this Station. Its second **%s** is open now too." % [
			_StationManagerScript.CHOICE_LEVEL, GameTerms.MEAL_SLOT,
		],
		Context.STATION_CHOICE, [], PRIORITY_PANEL)

	# Events.
	_add(&"event_preview", CATEGORY_EVENTS, "Events",
		"Some Days bring an **event** that changes the rules. Hover this icon to preview the next one and plan ahead.",
		Context.HOUR, [&"event_icon"], PRIORITY_NORMAL)
	_add(&"event_active", CATEGORY_EVENTS, "Event active",
		"Today's **event** is in effect until the Day ends. Hover the icon to check what it does.",
		Context.HOUR, [&"event_icon"], PRIORITY_URGENT)


static func _station_types_body() -> String:
	var lead := "Fill a Station's first 6 spots with the right cards and it becomes a **type**, with its own bonus."
	var example := load(EXAMPLE_STATION_PATH) as StationType
	if example == null:
		return lead
	var text := "%s For example, a **%s** needs **%s**." % [lead, example.display_name, example.get_requirements_text()]
	var perk := example.perk_for_level(1)
	if perk != null and not perk.description.is_empty():
		text += " Its bonus: %s." % perk.description
	return text + " Every type is listed in the **Collection**."


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
