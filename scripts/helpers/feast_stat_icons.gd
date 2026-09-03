class_name FeastStatIcons
extends RefCounted

## HUD pile icons and Kitchenware role chips. Single folder under assets/icons/stats/.

const FLAVOUR := preload("res://assets/icons/stats/energy.png")
const MULT := preload("res://assets/icons/stats/multiplier.png")
const GOLD := preload("res://assets/icons/stats/gold.png")
const MERCHANT_TOKEN := preload("res://assets/icons/stats/merchant_token.png")

const DOUBLE := preload("res://assets/icons/stats/empower_sigil.png")
const AGAIN := preload("res://assets/icons/stats/retrigger_sigil.png")
const PASS := preload("res://assets/icons/stats/segment_relay_sigil.png")
const PROOF := preload("res://assets/icons/stats/growth_sigil.png")

## Random pool for the scene-enter loading splash. Stats, ingredients, and kitchenware.
const LOADING_SPLASH: Array[Texture2D] = [
	FLAVOUR,
	MULT,
	GOLD,
	DOUBLE,
	AGAIN,
	PASS,
	PROOF,
	preload("res://assets/icons/food/ingredients/apple.png"),
	preload("res://assets/icons/food/seasonings/salt.png"),
	preload("res://assets/icons/food/ingredients/bacon.png"),
	preload("res://assets/icons/food/ingredients/coffee.png"),
	preload("res://assets/icons/kitchenware/skillet.png"),
	preload("res://assets/icons/kitchenware/chef_knife.png"),
	preload("res://assets/icons/kitchenware/cloche.png"),
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


static func get_sigil_icon(sigil_kind: TileCard.SigilKind) -> Texture2D:
	match sigil_kind:
		TileCard.SigilKind.ENERGY:
			return FLAVOUR
		TileCard.SigilKind.MULT:
			return MULT
		TileCard.SigilKind.GOLD:
			return GOLD
		TileCard.SigilKind.EMPOWER:
			return DOUBLE
		TileCard.SigilKind.RETRIGGER:
			return AGAIN
		TileCard.SigilKind.SEGMENT_RELAY:
			return PASS
		TileCard.SigilKind.GROWTH:
			return PROOF
		_:
			return null
