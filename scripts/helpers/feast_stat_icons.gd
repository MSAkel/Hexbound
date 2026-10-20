class_name FeastStatIcons
extends RefCounted

## HUD pile icons and Kitchenware stat chips. Single folder under assets/icons/stats/.

const FLAVOUR := preload("res://assets/icons/stats/flavour.png")
const MULT := preload("res://assets/icons/stats/mult.png")
const GOLD := preload("res://assets/icons/stats/gold.png")

const GARNISH := preload("res://assets/icons/stats/garnish.png")
const FIRE := preload("res://assets/icons/stats/fire.png")
const PASS := preload("res://assets/icons/stats/pass.png")

## Fallback for cards and staff that have no icon yet.
const PLACEHOLDER := preload("res://assets/icons/placeholder.png")

## Random pool for the scene-enter loading splash. Stats, ingredients, and kitchenware.
const LOADING_SPLASH: Array[Texture2D] = [
	FLAVOUR,
	MULT,
	GOLD,
	GARNISH,
	FIRE,
	PASS,
	preload("uid://c803xrilhj251"),
	preload("uid://b6mir3nxl7wph"),
	preload("uid://bt8vbmxevwq3o"),
	preload("uid://berds0aj0ward"),
	preload("uid://6h44uxn1am81"),
	preload("uid://xh37v80eccbf"),
]


static func get_product_icon(product: TileCard.Product) -> Texture2D:
	match product:
		TileCard.Product.FLAVOUR:
			return FLAVOUR
		TileCard.Product.GOLD:
			return GOLD
		TileCard.Product.MULTIPLIER:
			return MULT
		_:
			return null


## Stand-in art for "any card of this kind" in Meal requirement rows. Borrowed from a typical card of the kind.
static func get_ingredient_kind_icon(kind: StringName) -> Texture2D:
	match kind:
		TileCard.TAG_VEGETABLE:
			return preload("res://assets/icons/food/ingredients/vegetables/lettuce.png")
		TileCard.TAG_FRUIT:
			return preload("res://assets/icons/food/ingredients/fruits/apple.png")
		TileCard.TAG_MEAT:
			return preload("res://assets/icons/food/ingredients/meats/meat.png")
		TileCard.TAG_SEAFOOD:
			return preload("res://assets/icons/food/ingredients/seafood/shrimp.png")
		TileCard.TAG_DAIRY:
			return preload("res://assets/icons/food/ingredients/dairy/cheese.png")
		TileCard.TAG_SWEET:
			return preload("res://assets/icons/condiments/honey.png")
		TileCard.TAG_SEASONING:
			return preload("res://assets/icons/food/ingredients/seasonings/salt.png")
		TileCard.TAG_KITCHENWARE:
			return preload("res://assets/icons/kitchenware/chef_knife.png")
		_:
			return PLACEHOLDER


static func get_support_icon(role: TileCard.SupportRole) -> Texture2D:
	match role:
		TileCard.SupportRole.GARNISH:
			return GARNISH
		TileCard.SupportRole.FIRE:
			return FIRE
		_:
			return null
