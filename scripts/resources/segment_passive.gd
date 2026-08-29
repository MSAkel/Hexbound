class_name SegmentPassive
extends Resource

## Meta passive placed on map segments before a run. Empty character_id means global.

enum EffectType {
	ENERGY_OUTPUT_MULT,
	SUPPORT_RETRIGGER,
	PRODUCER_RETRIGGER,
	ENERGY_GROWTH,
	MULT_GROWTH,
	FIRST_PRODUCER_OUTPUT_MULT,
	FIRST_PRODUCER_EMPOWER,
	LAST_PRODUCER_OUTPUT_MULT,
	LAST_PRODUCER_EMPOWER,
	GOLD_CHANCE_BONUS,
	GOLD_FLAT_BONUS,
	BREAK_SAVE_CHANCE,
	ALTERNATING_OUTPUT_MULT,
	RELAY_OUTPUT_MULT,
	RELAY_EMPOWER,
	ADJACENCY_OUTPUT_MULT,
	FULL_OCCUPANCY_OUTPUT_MULT,
	ONE_TILE_OUTPUT_MULT,
	ONE_TILE_RETRIGGER,
	ONE_TILE_PERSONAL_GROWTH,
	ONE_TILE_BREAK_WARD,
	LAYOUT_SIGHTLINE,
	LAYOUT_END_RETRIGGER,
	LAYOUT_INWARD_MOMENTUM,
	LAYOUT_CLOSED_ORBIT,
	LAYOUT_COIL_CHARGE,
	LAYOUT_OUTWARD_PULSE,
	LAYOUT_DOWNSTROKE,
	LAYOUT_TURNAROUND,
	LAYOUT_COMPRESSION,
	LAYOUT_SINGULARITY,
}

@export var id: String = ""
## Empty means global. Non-empty restricts visibility to that layout.
@export var character_id: String = ""
@export var display_name: String = ""
@export_multiline var description: String = ""
@export var icon: Texture2D
@export var tile_cost: int = 1
@export var max_copies: int = 1
## Copy i unlocks when the unlock stat reaches this value. Empty grants all copies on first unlock.
@export var copy_thresholds: Array[int] = []
@export var effect_type: EffectType = EffectType.ENERGY_OUTPUT_MULT
@export var effect_value: float = 0.0
## Cadence, min adjacent neighbors, or similar integer extra.
@export var extra_int: int = 0
## Caps stored as a fraction, such as 0.30 for +30%.
@export var extra_float: float = 0.0
@export var unlock_condition: UnlockCondition
# Granted on profile load with no reveal toast. Use this for starter passives.
@export var starts_unlocked: bool = false


func is_global() -> bool:
	return character_id.is_empty()


func get_effect_summary() -> String:
	return description
