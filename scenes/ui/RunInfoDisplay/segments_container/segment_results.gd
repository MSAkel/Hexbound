extends PanelContainer

## One row in the run-info panel for a single map segment's turn score, multiplier, and gold.

var segment_index: int = -1

@onready var segment_score: Label = $HBoxContainer/SegmentScore
@onready var segment_multiplier: Label = $HBoxContainer/SegmentMultiplier
@onready var segment_gold: Label = $HBoxContainer/GoldContainer/SegmentGold

func _ready() -> void:
	Events.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	Events.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	_refresh(0, 0, 0)


func _on_segment_turn_results_changed(changed_index: int, score: int, multiplier: int, gold: int) -> void:
	if changed_index != segment_index:
		return
	_refresh(score, multiplier, gold)


func _on_segment_turn_results_reset() -> void:
	_refresh(0, 0, 0)


func _refresh(score: int, multiplier: int, gold: int) -> void:
	segment_score.text = str(score)
	segment_multiplier.text = str(multiplier)
	segment_gold.text = str(gold)
