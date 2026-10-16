class_name MerchantShopStyling
extends RefCounted

## Shared merchant shelf price chip look for cards and condiments.

const PRICE_FONT_GOLD := Color(0.78, 0.58, 0.12, 1.0)
const PRICE_FONT_UNAFFORDABLE := Color(0.62, 0.18, 0.14, 1.0)


static func format_price(amount: int) -> String:
	return "$%d" % amount


static func price_label_color(can_afford: bool) -> Color:
	return PRICE_FONT_GOLD if can_afford else PRICE_FONT_UNAFFORDABLE
