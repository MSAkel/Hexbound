class_name SegmentPassive
extends Resource

## Meta passive placed on map segments before a run. Empty character_id means global.

enum EffectType {
	SEGMENT_SCORE_MULT,
	SEGMENT_SCORE_FLAT,
	SUPPORT_RETRIGGER,
	CARD_OUTPUT_MULT,
	PRODUCTION_RETRIGGER,
}

@export var id: String = ""
## Empty means global. Non-empty restricts visibility to that character in future.
@export var character_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var tile_cost: int = 1
@export var max_copies: int = 1
@export var effect_type: EffectType = EffectType.SEGMENT_SCORE_MULT
@export var effect_value: float = 0.0
@export var unlock_condition: UnlockCondition
# Granted on profile load with no reveal toast. Use this for starter passives.
@export var starts_unlocked: bool = false


func is_global() -> bool:
	return character_id.is_empty()


func get_effect_summary() -> String:
	match effect_type:
		EffectType.SEGMENT_SCORE_MULT:
			return "+%d%% segment score" % int(round(effect_value * 100.0))
		EffectType.SEGMENT_SCORE_FLAT:
			return "+%d power each turn in this segment" % int(effect_value)
		EffectType.SUPPORT_RETRIGGER:
			return "Support cards: %d%% retrigger" % int(round(effect_value * 100.0))
		EffectType.CARD_OUTPUT_MULT:
			return "+%d%% power output for cards in this segment" % int(round(effect_value * 100.0))
		EffectType.PRODUCTION_RETRIGGER:
			return "Production cards: %d%% retrigger" % int(round(effect_value * 100.0))
	return description
