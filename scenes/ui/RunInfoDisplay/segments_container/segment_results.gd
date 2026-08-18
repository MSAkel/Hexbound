extends PanelContainer

## One row in the run-info panel for a single map segment's turn score, multiplier, and gold.

var segment_index: int = -1

@onready var segment_no: Label = $HBoxContainer/SegmentNoContainer/SegmentNo
@onready var segment_score: Label = $HBoxContainer/ScoreContainer/SegmentScore
@onready var segment_gold: Label = $HBoxContainer/GoldContainer/SegmentGold

var _score: int = 0
var _multiplier: int = 1
var _total_score: int = 0
var _gold: int = 0
var _score_counter: CountingNumber
var _gold_counter: CountingNumber


func _ready() -> void:
	_score_counter = CountingNumber.for_label(self, segment_score)
	_gold_counter = CountingNumber.for_label(self, segment_gold)
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	_sync_from_tile_map()


func _get_tile_map() -> HexTileMap:
	return get_tree().get_first_node_in_group("hex_map_group") as HexTileMap


func _sync_from_tile_map() -> void:
	var tile_map := _get_tile_map()
	if tile_map == null or segment_index < 0:
		_apply_results(0, 1, 0, 0, false)
		return

	var score := tile_map.get_segment_turn_score(segment_index)
	var multiplier := tile_map.get_segment_turn_multiplier(segment_index)
	var gold := tile_map.get_segment_turn_gold(segment_index)
	_apply_results(score, multiplier, score * multiplier, gold, false)
	_set_segment_no(segment_index + 1)


func _on_segment_turn_results_changed(changed_index: int, score: int, multiplier: int, total_score: int, gold: int) -> void:
	if changed_index != segment_index:
		return
	_apply_results(score, multiplier, total_score, gold)


func _on_segment_turn_results_reset() -> void:
	_apply_results(0, 1, 0, 0, false)


## Stores tooltip values and updates the score/gold labels.
func _apply_results(score: int, multiplier: int, total_score: int, gold: int, animate: bool = true) -> void:
	_score = score
	_multiplier = multiplier
	_total_score = total_score
	_gold = gold
	if animate:
		_score_counter.play(score)
		_gold_counter.play(gold)
	else:
		_score_counter.snap_to(score)
		_gold_counter.snap_to(gold)


func _set_segment_no(no: int) -> void:
	match no:
		1:
			segment_no.text = "1st"
		2:
			segment_no.text = "2nd"
		3:
			segment_no.text = "3rd"
		4:
			segment_no.text = "4th"
		5:
			segment_no.text = "5th"
		6:
			segment_no.text = "6th"
		7:
			segment_no.text = "7th"
		8:
			segment_no.text = "8th"
		9:
			segment_no.text = "9th"

func _on_mouse_entered() -> void:
	var tooltip := "Last Turn Results:\nScore: %s\nMultiplier: %s\nGold: %s\nTotal Score: %s\n\nRound Results: \nWIP" % [_score, _multiplier, _gold, _total_score]
	EventBus.toggle_tooltip.emit(true, tooltip, get_global_rect())
	# Highlight this segment's tiles on the map for as long as the tooltip is shown.
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.highlight_hovered_segment(segment_index)


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(segment_index)


func _exit_tree() -> void:
	if _score_counter != null:
		_score_counter.kill()
	if _gold_counter != null:
		_gold_counter.kill()
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(segment_index)
