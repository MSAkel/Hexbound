class_name MerchantShopStyling
extends RefCounted

## Shared merchant shelf price chip look for cards and condiments.

const PRICE_CHIP_BG := Color("E8D9B0")
const PRICE_CHIP_BORDER := Color("C9AB6B")
const PRICE_FONT_GOLD := Color(0.78, 0.58, 0.12, 1.0)
const PRICE_FONT_UNAFFORDABLE := Color(0.62, 0.18, 0.14, 1.0)


static func format_price(amount: int) -> String:
	return "$%d" % amount


static func price_chip_stylebox() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = PRICE_CHIP_BG
	style.border_width_left = 1
	style.border_width_top = 1
	style.border_width_right = 1
	style.border_width_bottom = 1
	style.border_color = PRICE_CHIP_BORDER
	style.corner_radius_top_left = 7
	style.corner_radius_top_right = 7
	style.corner_radius_bottom_right = 7
	style.corner_radius_bottom_left = 7
	style.shadow_size = 2
	style.shadow_color = Color(0, 0, 0, 0.22)
	style.content_margin_left = 12
	style.content_margin_top = 3
	style.content_margin_right = 12
	style.content_margin_bottom = 3
	return style


static func price_label_color(can_afford: bool) -> Color:
	return PRICE_FONT_GOLD if can_afford else PRICE_FONT_UNAFFORDABLE
