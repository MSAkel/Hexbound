extends PanelContainer

## One row in the run-info panel for a single map segment's turn score, multiplier, and gold.

var segment_index: int = -1

@onready var segment_score: Label = $HBoxContainer/SegmentScore
@onready var segment_multiplier: Label = $HBoxContainer/SegmentMultiplier
@onready var segment_gold: Label = $HBoxContainer/GoldContainer/SegmentGold
@onready var segment_total_score: Label = $HBoxContainer/SegmentTotalScore

func _ready() -> void:
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	_refresh(0, 1, 0, 0)


func _on_segment_turn_results_changed(changed_index: int, score: int, multiplier: int, totalScore: int, gold: int) -> void:
	if changed_index != segment_index:
		return
	_refresh(score, multiplier, totalScore, gold)


func _on_segment_turn_results_reset() -> void:
	_refresh(0, 1, 0, 0)


func _refresh(score: int, multiplier: int, totalScore: int, gold: int) -> void:
	segment_score.text = str(score)
	segment_multiplier.text = str(multiplier)
	segment_gold.text = str(gold)
	segment_total_score.text = str(totalScore)
