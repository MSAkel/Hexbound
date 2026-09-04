class_name Condiment
extends Resource

## One merchant condiment. Belt slots and shop stock hold these, not hand cards.

enum EffectType {
	GOLD_DROP,
	BORROWED_TIME,
	REWRITE_OMEN,
	FREE_REROLL,
	CONDIMENT_PACK,
	EMPOWER,
	ECHO,
	WARD,
	NEXT_TRIGGER_ENERGY,
	FORWARD_GIFT,
	MINT_SIP,
	OPENING_ROUND,
	CLOSING_ROUND,
	NEXT_TRIGGER_MULT,
}

enum TargetKind {
	NONE,
	TILE,
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


func needs_tile_target() -> bool:
	return target_kind == TargetKind.TILE


func fuse_lasts_two_turns() -> bool:
	return (
		effect_type == EffectType.FORWARD_GIFT
		or effect_type == EffectType.MINT_SIP
	)


func get_fuse_summary() -> String:
	match effect_type:
		EffectType.EMPOWER:
			return "Double (condiment)"
		EffectType.ECHO:
			return "Echo · next activation"
		EffectType.WARD:
			return "Ward · next break"
		EffectType.NEXT_TRIGGER_ENERGY:
			return "+%d Flavour · next fire" % int(effect_value)
		EffectType.NEXT_TRIGGER_MULT:
			return "+%d Mult · next fire" % int(round(effect_value))
		EffectType.FORWARD_GIFT:
			return "Forward Gift"
		EffectType.MINT_SIP:
			return "Mint Sip"
		EffectType.OPENING_ROUND:
			return "Opening Round · this hour"
		EffectType.CLOSING_ROUND:
			return "Closing Round · this hour"
		_:
			return display_name
