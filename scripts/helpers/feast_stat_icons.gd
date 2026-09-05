class_name FeastStatIcons
extends RefCounted

## HUD pile icons and Kitchenware stat chips. Single folder under assets/icons/stats/.

const FLAVOUR := preload("res://assets/icons/stats/flavour.png")
const MULT := preload("res://assets/icons/stats/mult.png")
const GOLD := preload("res://assets/icons/stats/gold.png")
const MERCHANT_TOKEN := preload("res://assets/icons/stats/merchant_token.png")

const DOUBLE := preload("res://assets/icons/stats/double.png")
const FIRE := preload("res://assets/icons/stats/fire.png")
const PASS := preload("res://assets/icons/stats/pass.png")
const PROOF := preload("res://assets/icons/stats/proof.png")

## Random pool for the scene-enter loading splash. Stats, ingredients, and kitchenware.
const LOADING_SPLASH: Array[Texture2D] = [
	FLAVOUR,
	MULT,
	GOLD,
	DOUBLE,
	FIRE,
	PASS,
	PROOF,
	preload("uid://c803xrilhj251"),
	preload("uid://b6mir3nxl7wph"),
	preload("uid://bt8vbmxevwq3o"),
	preload("uid://berds0aj0ward"),
	preload("uid://cw5birgpj1ymb"),
	preload("uid://6h44uxn1am81"),
	preload("uid://xh37v80eccbf"),
]


static func get_pile_icon(product: TileCard.Product) -> Texture2D:
	match product:
		TileCard.Product.SCORE:
			return FLAVOUR
		TileCard.Product.GOLD:
			return GOLD
		TileCard.Product.MULTIPLIER:
			return MULT
		_:
			return null


static func get_stat_icon(stat_kind: TileCard.StatKind) -> Texture2D:
	match stat_kind:
		TileCard.StatKind.FLAVOUR:
			return FLAVOUR
		TileCard.StatKind.MULT:
			return MULT
		TileCard.StatKind.GOLD:
			return GOLD
		TileCard.StatKind.DOUBLE:
			return DOUBLE
		TileCard.StatKind.FIRE:
			return FIRE
		TileCard.StatKind.PASS:
			return PASS
		TileCard.StatKind.PROOF:
			return PROOF
		_:
			return null
