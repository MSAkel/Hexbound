class_name FeastDisplay
extends RefCounted

## Player-facing Feast labels. Code enums stay unchanged.

const FLAVOUR := "Flavour"
const MULT := "Mult"
const RATING := "Rating"
const INGREDIENT := "Ingredient"
const CORE := "Core"
const SEASONING := "Seasoning"
const GOLD := "Gold"
const COURSE := "Course"
const SPOT := "Spot"
const FIRE_ORDER := "Fire Order"
const DAY := "Day"
const HOUR := "Hour"
const PASS := "Pass"
const CONDIMENTS := "Condiments"
const DISH := "Dish"

const PLACEHOLDER_ICON := preload("res://assets/icons/placeholder.png")


static func day_label(day_number: int) -> String:
	return "%s %d" % [DAY, day_number]


static func hours_left_label(hours: int) -> String:
	return str(hours)


static func hour_label(hour_number: int) -> String:
	return "%s %d" % [HOUR.to_upper(), hour_number]


static func course_label(course_number: int) -> String:
	return "%s %d" % [COURSE.to_upper(), course_number]


static func courses_count_label(course_count: int) -> String:
	return "%d %s" % [course_count, COURSE.to_upper() + "S"]


static func get_tile_card_shelf_label(card: TileCard) -> String:
	if card == null:
		return ""
	match card.type:
		TileCard.TileCardType.KITCHENWARE:
			return "Kitchenware"
		TileCard.TileCardType.INGREDIENT:
			return INGREDIENT
		TileCard.TileCardType.DISH:
			return DISH
	return card.get_card_kind_label().capitalize()


static func get_ingredient_kind_label(kind: StringName) -> String:
	match kind:
		TileCard.TAG_VEGETABLE:
			return "Vegetable"
		TileCard.TAG_FRUIT:
			return "Fruit"
		TileCard.TAG_GRAIN:
			return "Grain"
		TileCard.TAG_PROTEIN:
			return "Protein"
		TileCard.TAG_SEASONING:
			return SEASONING
		TileCard.TAG_BEVERAGE:
			return "Beverage"
		TileCard.TAG_KITCHENWARE:
			return "Kitchenware"
		TileCard.TAG_DISH:
			return "Dish"
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
	relay_mode: TileCard.RelayMode,
	support_role: TileCard.SupportRole
) -> String:
	var parts: Array[String] = []
	if relay_mode == TileCard.RelayMode.NEXT_SEGMENT:
		parts.append("Pass")
	if support_role != TileCard.SupportRole.NONE:
		var role_key: Variant = TileCard.SupportRole.find_key(support_role)
		if role_key != null:
			parts.append(String(role_key).capitalize())
	var product_label := _get_product_role_label(product)
	if not product_label.is_empty():
		parts.append(product_label)
	return " · ".join(parts)


static func _get_product_role_label(product: TileCard.Product) -> String:
	match product:
		TileCard.Product.FLAVOUR:
			return "Flavour"
		TileCard.Product.MULTIPLIER:
			return "Mult"
		TileCard.Product.GOLD:
			return "Gold"
		TileCard.Product.HYBRID:
			return "Hybrid"
		_:
			return ""
