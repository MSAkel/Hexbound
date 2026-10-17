class_name GameTerms
extends RefCounted

## Player-facing names for game terms. Code enums stay unchanged.
## Rename a term here. CardKeywordGlossary reads these and adds inflected forms, colour and tooltips.

const FLAVOUR := "Flavour"
const MULT := "Mult"
const RATING := "Rating"
const INGREDIENT := "Ingredient"
const KITCHENWARE := "Kitchenware"
const VEGETABLE := "Vegetable"
const FRUIT := "Fruit"
# The protein tag reads as Meat on cards. Seafood is its own kind.
const PROTEIN := "Meat"
const SEAFOOD := "Seafood"
const DAIRY := "Dairy"
const SWEET := "Sweet"
const SEASONING := "Seasoning"
const BEVERAGE := "Beverage"
const GOLD := "Gold"
const STATION := "Station"
const SPOT := "Spot"
const DAY := "Day"
const HOUR := "Hour"
const CONDIMENTS := "Condiments"
const MEAL := "Meal"
const DISH := "Dish"
const PASS := "Pass"
const MEAL_SLOT := "Meal Slot"
const HYBRID := "Hybrid"
const GARNISH := "Garnish"
const FOLLOWING := "Following"
const DESTROY := "Destroy"
const TRIGGER := "Trigger"


static func day_label(day_number: int) -> String:
	return "%s %d/%d" % [DAY, day_number, ScoreProgression.RUN_LENGTH_ROUNDS]


static func get_tile_card_type_label(card: TileCard) -> String:
	if card == null:
		return ""
	match card.type:
		TileCard.TileCardType.KITCHENWARE:
			return KITCHENWARE
		TileCard.TileCardType.INGREDIENT:
			return INGREDIENT
		TileCard.TileCardType.MEAL:
			return MEAL
	return card.get_card_kind_label().capitalize()


static func get_ingredient_kind_label(kind: StringName) -> String:
	match kind:
		TileCard.TAG_VEGETABLE:
			return VEGETABLE
		TileCard.TAG_FRUIT:
			return FRUIT
		TileCard.TAG_PROTEIN:
			return PROTEIN
		TileCard.TAG_SEAFOOD:
			return SEAFOOD
		TileCard.TAG_DAIRY:
			return DAIRY
		TileCard.TAG_SWEET:
			return SWEET
		TileCard.TAG_SEASONING:
			return SEASONING
		TileCard.TAG_BEVERAGE:
			return BEVERAGE
		TileCard.TAG_KITCHENWARE:
			return KITCHENWARE
		TileCard.TAG_DISH:
			return DISH
		_:
			return ""


static func format_ingredient_tags_label(tags: Array[StringName]) -> String:
	var parts: PackedStringArray = []
	for tag: StringName in tags:
		if tag == &"":
			continue
		var label := get_ingredient_kind_label(tag)
		if label.is_empty() or label in parts:
			continue
		parts.append(label)
	return " · ".join(parts)


static func get_role_label(
	product: TileCard.Product,
	support_role: TileCard.SupportRole
) -> String:
	var parts: Array[String] = []
	var support_label := _get_support_role_label(support_role)
	if not support_label.is_empty():
		parts.append(support_label)
	var product_label := _get_product_role_label(product)
	if not product_label.is_empty():
		parts.append(product_label)
	return " · ".join(parts)


static func _get_support_role_label(support_role: TileCard.SupportRole) -> String:
	match support_role:
		TileCard.SupportRole.GARNISH:
			return GARNISH
		TileCard.SupportRole.FIRE:
			return TRIGGER
		_:
			return ""


static func _get_product_role_label(product: TileCard.Product) -> String:
	match product:
		TileCard.Product.FLAVOUR:
			return FLAVOUR
		TileCard.Product.MULTIPLIER:
			return MULT
		TileCard.Product.GOLD:
			return GOLD
		TileCard.Product.HYBRID:
			return HYBRID
		_:
			return ""
