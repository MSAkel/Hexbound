extends PanelContainer

const SEGMENT_RESULTS_SCENE := preload(
	"res://scenes/ui/RunInfoDisplay/segments_container/segment_results.tscn"
)

@onready var prev_turn_button: TextureButton = $VBoxContainer/TurnsContainer/PrevTurnButton
@onready var turn_label: Label = $VBoxContainer/TurnsContainer/TurnLabel
@onready var next_turn_button: TextureButton = $VBoxContainer/TurnsContainer/NextTurnButton
@onready var segment_results_list: VBoxContainer = $VBoxContainer/SegmentResultsList
@onready var score_total_number: Label = $VBoxContainer/TurnTotalContainer/ScoreContainer/ScoreTotalNumber
@onready var gold_total_number: Label = $VBoxContainer/TurnTotalContainer/GoldContainer/GoldTotalNumber
@onready var seg_icon: TextureRect = $VBoxContainer/LabelsMargin/LabelsContainer/SegContainer/SegIcon
@onready var energy_icon: TextureRect = $VBoxContainer/LabelsMargin/LabelsContainer/PowerContainer/EnergyIcon
@onready var mult_icon: TextureRect = $VBoxContainer/LabelsMargin/LabelsContainer/MultContainer/MultIcon
@onready var score_icon: TextureRect = $VBoxContainer/LabelsMargin/LabelsContainer/ScoreContainer/ScoreIcon
@onready var gold_icon: TextureRect = $VBoxContainer/LabelsMargin/LabelsContainer/GoldContainer/GoldIcon

## Completed turn snapshots for the current round. Each entry matches capture_segment_turn_snapshot().
var _turn_history: Array = []
var _viewed_turn_index: int = 0
var _resolving_turn: bool = false
var _score_total_counter: CountingNumber
var _gold_total_counter: CountingNumber
var _punch_tweens: Dictionary = {}
## Score footer during live resolve. Grows only as each segment's equals beat lands.
var _live_revealed_score: int = 0

const PUNCH_SCALE := 1.12
const PUNCH_DURATION := 0.18


func _ready() -> void:
	_score_total_counter = _make_stat_counter(score_total_number)
	_gold_total_counter = _make_stat_counter(gold_total_number)

	prev_turn_button.pressed.connect(_on_prev_turn_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)

	call_deferred("_build_segment_rows")

	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.segment_turn_completed.connect(_on_segment_turn_completed)
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_score_revealed.connect(_on_segment_score_revealed)
	EventBus.round_changed.connect(_on_round_changed)

	_refresh_view(false)


func _on_turn_ended() -> void:
	_resolving_turn = true
	_live_revealed_score = 0
	_viewed_turn_index = _turn_history.size()
	_set_rows_live_mode(true)
	_refresh_view(false)


func _on_segment_turn_completed(_turn_number: int, snapshot: Dictionary) -> void:
	_turn_history.append(snapshot)
	_resolving_turn = false
	_viewed_turn_index = _turn_history.size() - 1
	_set_rows_live_mode(false)
	_refresh_view(true)


func _on_segment_turn_results_changed(
	_changed_index: int,
	_score: int,
	_multiplier: int,
	_total_score: int,
	_gold: int
) -> void:
	if not _is_viewing_live_turn():
		return
	# Gold can land during activations. Score waits until the overlay flies into the panel.
	_update_live_gold_total(true)


func _on_segment_score_revealed(_segment_index: int, total_score: int) -> void:
	if not _is_viewing_live_turn():
		return
	_live_revealed_score += total_score
	_play_counter(_score_total_counter, _live_revealed_score, score_total_number)


func _on_round_changed(_new_round: int) -> void:
	_turn_history.clear()
	_viewed_turn_index = 0
	_resolving_turn = false
	_set_rows_live_mode(_resolving_turn)
	_refresh_view(false)


func _on_prev_turn_pressed() -> void:
	if _viewed_turn_index <= 0:
		return
	_viewed_turn_index -= 1
	_refresh_view(true)


func _on_next_turn_pressed() -> void:
	if _viewed_turn_index >= _get_latest_view_index():
		return
	_viewed_turn_index += 1
	_refresh_view(true)


func _get_latest_view_index() -> int:
	if _resolving_turn:
		return _turn_history.size()
	return maxi(_turn_history.size() - 1, 0)


func _is_viewing_live_turn() -> bool:
	return _resolving_turn and _viewed_turn_index == _turn_history.size()


func _set_rows_live_mode(enabled: bool) -> void:
	for child in segment_results_list.get_children():
		if child.has_method("set_accepts_live_updates"):
			child.set_accepts_live_updates(enabled)


func _refresh_view(animate: bool) -> void:
	_update_turn_label()
	_update_navigation_buttons()

	if _is_viewing_live_turn():
		_set_rows_live_mode(true)
		_sync_rows_from_tile_map(animate)
		return

	_set_rows_live_mode(false)
	if _turn_history.is_empty():
		_apply_empty_snapshot(animate)
		return

	var snapshot: Dictionary = _turn_history[_viewed_turn_index]
	_apply_snapshot(snapshot, animate)


func _update_turn_label() -> void:
	turn_label.text = "Turn %d" % (_viewed_turn_index + 1)


func _update_navigation_buttons() -> void:
	prev_turn_button.disabled = _viewed_turn_index <= 0
	next_turn_button.disabled = _viewed_turn_index >= _get_latest_view_index()


func _apply_snapshot(snapshot: Dictionary, animate: bool) -> void:
	var segments: Array = snapshot.get("segments", [])
	for child in segment_results_list.get_children():
		var segment_index: int = child.segment_index
		if segment_index < 0 or segment_index >= segments.size():
			child.apply_turn_snapshot(0, 1, 0, 0, animate)
			continue

		var segment_data: Dictionary = segments[segment_index]
		child.apply_turn_snapshot(
			int(segment_data.get("score", 0)),
			int(segment_data.get("multiplier", 1)),
			int(segment_data.get("total_score", 0)),
			int(segment_data.get("gold", 0)),
			animate
		)

	_update_turn_totals(
		int(snapshot.get("total_score", 0)),
		int(snapshot.get("total_gold", 0)),
		animate
	)


func _apply_empty_snapshot(animate: bool) -> void:
	for child in segment_results_list.get_children():
		child.apply_turn_snapshot(0, 1, 0, 0, animate)
	_update_turn_totals(0, 0, animate)


func _sync_rows_from_tile_map(animate: bool) -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		_apply_empty_snapshot(animate)
		return

	for child in segment_results_list.get_children():
		var segment_index: int = child.segment_index
		var score := tile_map.get_segment_turn_score(segment_index)
		var multiplier := tile_map.get_segment_turn_multiplier(segment_index)
		var gold := tile_map.get_segment_turn_gold(segment_index)
		child.apply_turn_snapshot(score, multiplier, score * multiplier, gold, animate, false)

	_update_live_gold_total(animate)
	_score_total_counter.snap_to(_live_revealed_score)


func _update_live_gold_total(animate: bool) -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		if animate:
			_play_counter(_gold_total_counter, 0, gold_total_number)
		else:
			_gold_total_counter.snap_to(0)
		return

	var snapshot: Dictionary = tile_map.capture_segment_turn_snapshot()
	var total_gold := int(snapshot.get("total_gold", 0))
	if animate:
		_play_counter(_gold_total_counter, total_gold, gold_total_number)
	else:
		_gold_total_counter.snap_to(total_gold)


func _update_turn_totals_from_tile_map(animate: bool) -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		_update_turn_totals(0, 0, animate)
		return

	var snapshot: Dictionary = tile_map.capture_segment_turn_snapshot()
	_update_turn_totals(
		int(snapshot.get("total_score", 0)),
		int(snapshot.get("total_gold", 0)),
		animate
	)


func _update_turn_totals(total_score: int, total_gold: int, animate: bool) -> void:
	if animate:
		_play_counter(_score_total_counter, total_score, score_total_number)
		_play_counter(_gold_total_counter, total_gold, gold_total_number)
	else:
		_score_total_counter.snap_to(total_score)
		_gold_total_counter.snap_to(total_gold)


func _make_stat_counter(label: Label) -> CountingNumber:
	return CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: label.text = _format_stat(as_int)
	)


func _format_stat(value: int) -> String:
	return "-" if value == 0 else str(value)


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


## Creates one segment_results row for each map segment after the board is generated.
func _build_segment_rows() -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		return

	for child in segment_results_list.get_children():
		child.queue_free()

	for segment_index in tile_map.get_segment_count():
		var row: PanelContainer = SEGMENT_RESULTS_SCENE.instantiate()
		row.segment_index = segment_index
		segment_results_list.add_child(row)

	_set_rows_live_mode(_is_viewing_live_turn())
	_refresh_view(false)


func _exit_tree() -> void:
	if _score_total_counter != null:
		_score_total_counter.kill()
	if _gold_total_counter != null:
		_gold_total_counter.kill()


## Column-header tooltips sit under the hovered icon, not the full segments panel.
func _on_seg_icon_mouse_entered() -> void:
	EventBus.toggle_tooltip.emit(true, "Segment", seg_icon.get_global_rect())


func _on_seg_icon_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_energy_icon_mouse_entered() -> void:
	EventBus.toggle_tooltip.emit(true, "Energy", energy_icon.get_global_rect())


func _on_energy_icon_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_mult_icon_mouse_entered() -> void:
	EventBus.toggle_tooltip.emit(true, "Mult", mult_icon.get_global_rect())


func _on_mult_icon_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_score_icon_mouse_entered() -> void:
	EventBus.toggle_tooltip.emit(true, "Score", score_icon.get_global_rect())


func _on_score_icon_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")


func _on_gold_icon_mouse_entered() -> void:
	EventBus.toggle_tooltip.emit(true, "Gold", gold_icon.get_global_rect())


func _on_gold_icon_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
