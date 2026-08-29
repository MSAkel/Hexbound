class_name UnlockCondition
extends Resource

## Typed unlock gate for a segment passive. Evaluated against profile stats and run snapshots.

enum Type {
	LIFETIME_TRIGGERS,
	WIN_RUN,
	GOLD_HELD,
	SEGMENT_SCORE_SINGLE_TURN,
	FULL_MAP_CARDS,
	TRIGGERS_SINGLE_TURN,
	MANUAL_LOCK,
	PRODUCER_TRIGGERS,
	SUPPORT_TRIGGERS,
	PRODUCER_RETRIGGERS,
	SUPPORT_RETRIGGERS_IN_RUN,
	RUNS_COMPLETED,
	WIN_DIFFICULTY,
	GOLD_EARNED_IN_RUN,
	ENERGY_CARD_TRIGGERS_IN_RUN,
	MULT_CARD_TRIGGERS_IN_RUN,
	ENERGY_BONUS_IN_RUN,
	MULT_BONUS_IN_RUN,
	CARDS_BROKEN,
	BREAKS_PREVENTED_BY_FUSE,
	ALTERNATING_ACTIVATIONS,
	SPECTRUM_TURNS,
	SUPPORT_THEN_PRODUCER,
	SUPPORT_AFFECTED_PRODUCERS,
	ADJACENT_SAME_PRODUCT_TRIGGERS,
	ONE_TILE_ACTIVATIONS,
	ONE_TILE_BREAKS,
	ONE_TILE_SAME_CARD_TRIGGERS_IN_RUN,
	LAST_PRODUCER_TRIGGERS,
	FULL_SEGMENT_TURNS,
	RESONANT_ARRAY_FILL,
	LAYOUT_LEVEL,
	PRODUCER_RETRIGGERS_OR_TURN_TRIGGERS,
	WIN_DIFFICULTY_AND_GOLD,
}

@export var condition_type: Type = Type.MANUAL_LOCK
@export var threshold: int = 0
## Second gate for OR unlocks or Mult bonus stored as tenths (15 = +1.5).
@export var extra_threshold: int = 0
## Player-facing difficulty 1 through 5. Maps to Difficulty.Level 0 through 4.
@export var difficulty_level: int = 0
## Used by WIN_RUN and LAYOUT_LEVEL. Empty means any layout.
@export var character_id: String = ""
@export_multiline var description: String = ""


func get_progress_label(current_value: int) -> String:
	if condition_type == Type.MANUAL_LOCK:
		return description
	if threshold <= 0:
		return description
	return "%d / %d" % [mini(current_value, threshold), threshold]


func get_progress_ratio(current_value: int) -> float:
	if condition_type == Type.MANUAL_LOCK or threshold <= 0:
		return 0.0
	return clampf(float(current_value) / float(threshold), 0.0, 1.0)
