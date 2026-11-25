class_name IngredientKindRules
extends RefCounted

## Ingredient kind rules. Every Ingredient gives the same base Flavour (`BASE_FLAVOUR`) and follows
## one shared rule set by its kind, so Ingredient cards carry no script of their own.
## The rule is printed on its own line on the card and the tooltip (`TileCard.get_description_text`).
## All numbers untuned. Design: the Option D tab of the Ingredient Design Sheet.
##
## - Meat: +5 Flavour for each adjacent Seasoning.
## - Seafood: +5 Flavour for each adjacent Fruit.
## - Seasoning: +5 Flavour for each adjacent Seasoning.
## - Vegetable: +5 Flavour per different kind of adjacent Ingredient.
## - Fruit: +5 Flavour for each adjacent Kitchenware.
## - Sweet: Desserts and Beverages on this Station gain +1 Mult per Sweet (read by MealCard).
## - Dairy: +10 Flavour each time a Kitchenware triggers it this Hour.

const BASE_FLAVOUR := 15

const MEAT_PER_SEASONING := 5.0
const SEAFOOD_PER_FRUIT := 5.0
const SEASONING_PER_SEASONING := 5.0
const VEGETABLE_PER_KIND := 5.0
const FRUIT_PER_KITCHENWARE := 5.0
const DAIRY_PER_PREPARATION := 10.0
const SWEET_MEAL_MULT := 1.0

const RULE_KINDS: Array[StringName] = [
	TileCard.TAG_MEAT,
	TileCard.TAG_SEAFOOD,
	TileCard.TAG_SEASONING,
	TileCard.TAG_VEGETABLE,
	TileCard.TAG_FRUIT,
	TileCard.TAG_SWEET,
	TileCard.TAG_DAIRY,
]


## The kind whose rule this card follows: its first printed rule kind. Empty for anything that is
## not an Ingredient. Kinds a Kitchenware status lends never change which rule a card follows.
static func rule_kind(card: TileCard) -> StringName:
	if card == null or card.type != TileCard.TileCardType.INGREDIENT:
		return &""
	for tag: StringName in card.ingredient_tags:
		if tag in RULE_KINDS:
			return tag
	return &""


## Tooltip text for a kind's rule. Empty when the kind has none.
static func rule_text(kind: StringName) -> String:
	match kind:
		TileCard.TAG_MEAT:
			return "+%d {flavour} for each adjacent Seasoning." % int(MEAT_PER_SEASONING)
		TileCard.TAG_SEAFOOD:
			return "+%d {flavour} for each adjacent Fruit." % int(SEAFOOD_PER_FRUIT)
		TileCard.TAG_SEASONING:
			return "+%d {flavour} for each adjacent Seasoning." % int(SEASONING_PER_SEASONING)
		TileCard.TAG_VEGETABLE:
			return "+%d {flavour} for each different kind of adjacent Ingredient." % int(VEGETABLE_PER_KIND)
		TileCard.TAG_FRUIT:
			return "+%d {flavour} for each adjacent Kitchenware." % int(FRUIT_PER_KITCHENWARE)
		TileCard.TAG_SWEET:
			return "Desserts and Beverages on this Station gain +%d {mult}." % int(SWEET_MEAL_MULT)
		TileCard.TAG_DAIRY:
			return "+%d {flavour} each time a Kitchenware triggers it this Turn." % int(DAIRY_PER_PREPARATION)
	return ""


## Extra Flavour the card's kind rule adds on this trigger (0 for Sweet, which pays through Meals).
static func flavour_bonus(card: TileCard, tile: Hex) -> float:
	var kind := rule_kind(card)
	if kind == &"" or tile == null:
		return 0.0
	match kind:
		TileCard.TAG_MEAT:
			return MEAT_PER_SEASONING * float(preview_cards(card, tile).size())
		TileCard.TAG_SEAFOOD:
			return SEAFOOD_PER_FRUIT * float(preview_cards(card, tile).size())
		TileCard.TAG_SEASONING:
			return SEASONING_PER_SEASONING * float(preview_cards(card, tile).size())
		TileCard.TAG_VEGETABLE:
			return VEGETABLE_PER_KIND * float(_adjacent_kinds(card, tile).size())
		TileCard.TAG_FRUIT:
			return FRUIT_PER_KITCHENWARE * float(preview_cards(card, tile).size())
		TileCard.TAG_DAIRY:
			return DAIRY_PER_PREPARATION * float(card.prep_statuses.size() + card.hour_times_prepared)
	return 0.0


## Placed cards the kind rule is reading, for hover previews.
static func preview_cards(card: TileCard, tile: Hex) -> Array[TileCard]:
	var cards: Array[TileCard] = []
	if tile == null:
		return cards
	match rule_kind(card):
		TileCard.TAG_MEAT:
			return card._cards_by_kind(tile, TileCard.TAG_SEASONING, TileCard.QueryScope.ADJACENT)
		TileCard.TAG_SEAFOOD:
			return card._cards_by_kind(tile, TileCard.TAG_FRUIT, TileCard.QueryScope.ADJACENT)
		TileCard.TAG_SEASONING:
			return card._cards_by_kind(tile, TileCard.TAG_SEASONING, TileCard.QueryScope.ADJACENT)
		TileCard.TAG_VEGETABLE:
			return card._get_all_adjacent_tile_cards(tile, TileCard.TileCardType.INGREDIENT)
		TileCard.TAG_FRUIT:
			return card._cards_by_kind(tile, TileCard.TAG_KITCHENWARE, TileCard.QueryScope.ADJACENT)
	return cards


## +Mult a Dessert or Beverage gets from the Sweets on its own station.
static func sweet_meal_mult(meal: MealCard, tile: Hex) -> float:
	if meal == null or tile == null or tile.map == null:
		return 0.0
	var is_target := meal.meal_category == MealCard.MealCategory.DESSERT \
		or meal.meal_category == MealCard.MealCategory.BEVERAGE \
		or meal.has_ingredient_tag(TileCard.TAG_BEVERAGE)
	if not is_target:
		return 0.0
	return SWEET_MEAL_MULT * float(sweets_on_station(meal, tile).size())


## Sweets seated on the Meal's station regular spots.
static func sweets_on_station(meal: MealCard, tile: Hex) -> Array[TileCard]:
	var sweets: Array[TileCard] = []
	for card: TileCard in meal._own_station_cards(tile):
		if card.is_active and rule_kind(card) == TileCard.TAG_SWEET:
			sweets.append(card)
	return sweets


## Different recipe kinds among the adjacent Ingredients, counting kinds lent by statuses.
static func _adjacent_kinds(card: TileCard, tile: Hex) -> Dictionary:
	var kinds := {}
	for neighbour: TileCard in preview_cards(card, tile):
		for tag: StringName in neighbour.get_kind_tags():
			if tag in TileCard.RECIPE_INGREDIENT_TAGS:
				kinds[tag] = true
	return kinds
