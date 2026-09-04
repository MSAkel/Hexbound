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
		TileCard.TileCardType.UTILITY:
			return "Utility"
		TileCard.TileCardType.KITCHENWARE:
			return "Kitchenware"
		TileCard.TileCardType.INGREDIENT:
			return INGREDIENT
	return card.get_card_kind_label().capitalize()


static func get_stat_label(stat_kind: TileCard.StatKind, product: TileCard.Product) -> String:
	if stat_kind != TileCard.StatKind.NONE:
		var key: Variant = TileCard.StatKind.find_key(stat_kind)
		if key != null:
			return String(key).capitalize()
	if product == TileCard.Product.HYBRID:
		return "Hybrid"
	return ""
