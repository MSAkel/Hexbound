extends PanelContainer

## One row in the run-info panel for a single map segment's turn Energy, multiplier, Score, and gold.

var segment_index: int = -1

@onready var segment_no: Label = $HBoxContainer/SegmentNo
@onready var segment_power: Label = $HBoxContainer/SegmentPower
@onready var multiplier_prefix: Label = $HBoxContainer/MultiplierContainer/x
@onready var segment_multiplier: Label = $HBoxContainer/MultiplierContainer/SegmentMultiplier
@onready var segment_total_score: Label = $HBoxContainer/SegmentTotalScore
@onready var segment_gold: Label = $HBoxContainer/SegmentGold

var _score: int = 0
var _multiplier: int = 1
var _total_score: int = 0
var _gold: int = 0
## Live resolve hides Score until this segment's equals beat.
var _score_revealed: bool = true
var _accepts_live_updates: bool = true
var _power_counter: CountingNumber
var _multiplier_counter: CountingNumber
var _total_score_counter: CountingNumber
var _gold_counter: CountingNumber
var _punch_tweens: Dictionary = {}

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18


func _ready() -> void:
	_power_counter = _make_stat_counter(segment_power)
	_multiplier_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: _apply_multiplier_display(as_int)
	)
	_total_score_counter = _make_stat_counter(segment_total_score)
	_gold_counter = _make_stat_counter(segment_gold)
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	EventBus.segment_score_revealed.connect(_on_segment_score_revealed)
	_set_segment_no(segment_index + 1)
	_sync_from_tile_map()


func set_accepts_live_updates(enabled: bool) -> void:
	_accepts_live_updates = enabled
	if enabled:
		_score_revealed = false


func apply_turn_snapshot(
	score: int,
	multiplier: int,
	total_score: int,
	gold: int,
	animate: bool = true,
	reveal_score: bool = true
) -> void:
	if reveal_score:
		_score_revealed = true
	_apply_results(score, multiplier, total_score, gold, animate)


func _get_tile_map() -> HexTileMap:
	return get_tree().get_first_node_in_group("hex_map_group") as HexTileMap


func _sync_from_tile_map() -> void:
	if not _accepts_live_updates:
		return

	var tile_map := _get_tile_map()
	if tile_map == null or segment_index < 0:
		_apply_results(0, 1, 0, 0, false)
		return

	var score := tile_map.get_segment_turn_score(segment_index)
	var multiplier := tile_map.get_segment_turn_multiplier(segment_index)
	var gold := tile_map.get_segment_turn_gold(segment_index)
	_apply_results(score, multiplier, 0, gold, false)


func _on_segment_turn_results_changed(
	changed_index: int,
	score: int,
	multiplier: int,
	_total_score: int,
	gold: int
) -> void:
	if not _accepts_live_updates or changed_index != segment_index:
		return
	# Keep Score hidden until the equals beat. Energy, Mult, and Gold update live.
	_apply_results(score, multiplier, 0, gold)


func _on_segment_turn_results_reset() -> void:
	if not _accepts_live_updates:
		return
	_score_revealed = false
	_apply_results(0, 1, 0, 0, false)


func _on_segment_score_revealed(changed_index: int, total_score: int) -> void:
	if changed_index != segment_index:
		return
	_score_revealed = true
	_total_score = total_score
	_play_counter(_total_score_counter, total_score, segment_total_score)


## Stores tooltip values and updates the row labels.
func _apply_results(
	score: int,
	multiplier: int,
	total_score: int,
	gold: int,
	animate: bool = true
) -> void:
	_score = score
	_multiplier = multiplier
	_total_score = total_score
	_gold = gold

	if animate:
		_play_counter(_power_counter, score, segment_power)
		_play_counter(_multiplier_counter, multiplier, segment_multiplier)
		if _score_revealed:
			_play_counter(_total_score_counter, total_score, segment_total_score)
		else:
			_total_score_counter.snap_to(0)
		_play_counter(_gold_counter, gold, segment_gold)
	else:
		_power_counter.snap_to(score)
		_multiplier_counter.snap_to(multiplier)
		_total_score_counter.snap_to(total_score if _score_revealed else 0)
		_gold_counter.snap_to(gold)
	_apply_multiplier_display(multiplier)


func _make_stat_counter(label: Label) -> CountingNumber:
	return CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: label.text = _format_stat(as_int)
	)


func _format_stat(value: int) -> String:
	return "-" if value == 0 else str(value)


func _apply_multiplier_display(multiplier: int) -> void:
	var has_activity := _score > 0 or _total_score > 0 or _gold > 0
	multiplier_prefix.visible = multiplier > 1
	if multiplier <= 1 and not has_activity:
		segment_multiplier.text = "-"
	else:
		segment_multiplier.text = str(multiplier)


func _play_counter(counter: CountingNumber, target: int, punch_target: Control) -> void:
	var tween := counter.play(target)
	if tween != null:
		_punch(punch_target)


func _punch(control: Control) -> void:
	if control == null:
		return

	var existing: Variant = _punch_tweens.get(control)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE

	var duration := PUNCH_DURATION / GameManager.game_speed
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(PUNCH_SCALE, PUNCH_SCALE), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tweens[control] = tween


func _set_segment_no(no: int) -> void:
	if no <= 0:
		segment_no.text = "-"
		return

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
		_:
			segment_no.text = "%dth" % no


## Anchor on the segments panel right edge, vertically aligned to this row.
func _get_tooltip_anchor_rect() -> Rect2:
	var segments_container := _get_segments_container()
	var row_rect := get_global_rect()
	if segments_container == null:
		return row_rect

	var container_rect := segments_container.get_global_rect()
	return Rect2(
		Vector2(container_rect.end.x, row_rect.position.y),
		Vector2(0.0, row_rect.size.y)
	)


func _get_segments_container() -> Control:
	var node: Node = self
	while node != null:
		if node.name == "SegmentsContainer" and node is PanelContainer:
			return node as Control
		node = node.get_parent()
	return null


func _on_mouse_entered() -> void:
	var score_line := (
		"%s × %s = %s" % [_score, _multiplier, _total_score]
		if _score_revealed
		else "—"
	)
	var tooltip := (
		"Turn Results:\nEnergy: %s\nMultiplier: %s\nGold: %s\nScore: %s"
		% [_score, _multiplier, _gold, score_line]
	)
	EventBus.toggle_tooltip.emit(
		true,
		tooltip,
		_get_tooltip_anchor_rect(),
		Tooltip.Placement.RIGHT_OF_ANCHOR
	)
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
	if _power_counter != null:
		_power_counter.kill()
	if _multiplier_counter != null:
		_multiplier_counter.kill()
	if _total_score_counter != null:
		_total_score_counter.kill()
	if _gold_counter != null:
		_gold_counter.kill()
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(segment_index)
