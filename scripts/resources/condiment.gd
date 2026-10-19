class_name Condiment
extends Resource

## One merchant condiment. Belt slots and shop stock hold these, not hand cards.

enum EffectType {
	GOLD_DROP,
	CONDIMENT_PACK,
	GARNISH,
	ECHO,
	WARD,
	NEXT_TRIGGER_ENERGY,
	MINT_SIP,
	NEXT_TRIGGER_MULT,
	THROW_OUT,
	STAR_UP,
	SEND_BACK,
	DUPLICATE_ORDER,
	SWAP_SPOTS,
}

enum TargetKind {
	NONE,
	TILE,
	TWO_TILE,
}

@export var id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var liquid_color: Color = Color(0.55, 0.82, 0.95, 1.0)
@export var base_price: int = 4
@export var effect_type: EffectType = EffectType.GOLD_DROP
@export var effect_value: float = 0.0
@export var target_kind: TargetKind = TargetKind.NONE


func get_shop_price() -> int:
	var multiplier := Difficulty.get_merchant_price_multiplier(GameManager.selected_difficulty)
	return maxi(1, int(round(float(base_price) * multiplier)))


## Gold paid when dropped on the sell panel. Half the base price, like staff.
func get_sell_value() -> int:
	return maxi(1, floori(base_price / 2.0))


func needs_tile_target() -> bool:
	return target_kind == TargetKind.TILE or target_kind == TargetKind.TWO_TILE


func needs_two_tile_target() -> bool:
	return target_kind == TargetKind.TWO_TILE


## Name and description for hover tooltips, with glossary tokens resolved.
func get_tooltip_text() -> String:
	return "%s\n%s" % [display_name, CardKeywordGlossary.to_plain(description)]


func get_fuse_summary() -> String:
	return CardKeywordGlossary.to_plain(_get_fuse_summary_source())


func _get_fuse_summary_source() -> String:
	match effect_type:
		EffectType.GARNISH:
			return "{garnish} (condiment)"
		EffectType.ECHO:
			return "Echo · next {trigger}"
		EffectType.WARD:
			return "Ward · next {destroy}"
		EffectType.NEXT_TRIGGER_ENERGY:
			return "+%d {flavour} · next {trigger}" % int(effect_value)
		EffectType.NEXT_TRIGGER_MULT:
			return "+%d {mult} · next {trigger}" % int(round(effect_value))
		EffectType.MINT_SIP:
			return "Mint Sip"
		EffectType.THROW_OUT:
			return "{destroy} seated card, gain random card"
		EffectType.STAR_UP:
			return "+1 star on seated card"
		EffectType.SEND_BACK:
			return "Return a copy per star to hand"
		EffectType.DUPLICATE_ORDER:
			return "Copy seated card to hand"
		EffectType.SWAP_SPOTS:
			return "Swap two seated cards"
		_:
			return display_name
