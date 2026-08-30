class_name Potion
extends Resource

## One merchant drink. Belt slots and shop stock hold these, not hand cards.

enum EffectType {
	GOLD_DROP,
	BORROWED_TIME,
	REWRITE_OMEN,
	FREE_REROLL,
	POTION_PACK,
	EMPOWER,
	ECHO,
	WARD,
	BATON,
	FORWARD_GIFT,
	MINT_SIP,
	OPENING_ROUND,
	CLOSING_ROUND,
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
			return "Empowered (potion)"
		EffectType.ECHO:
			return "Echo · next activation"
		EffectType.WARD:
			return "Ward · next break"
		EffectType.BATON:
			return "Baton · next activation"
		EffectType.FORWARD_GIFT:
			return "Forward Gift"
		EffectType.MINT_SIP:
			return "Mint Sip"
		EffectType.OPENING_ROUND:
			return "Opening Round · this turn"
		EffectType.CLOSING_ROUND:
			return "Closing Round · this turn"
		_:
			return display_name
