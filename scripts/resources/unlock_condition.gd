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
}

@export var condition_type: Type = Type.MANUAL_LOCK
@export var threshold: int = 0
## Used by WIN_RUN when a specific character must win. Empty means any character.
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
