extends PanelContainer

const SEGMENT_RESULTS_SCENE := preload(
	"res://scenes/ui/RunInfoDisplay/segments_container/segment_results.tscn"
)

@onready var prev_turn_button: TextureButton = $VBoxContainer/TurnsContainer/PrevTurnButton
@onready var turn_label: Label = $VBoxContainer/TurnsContainer/TurnLabel
@onready var next_turn_button: TextureButton = $VBoxContainer/TurnsContainer/NextTurnButton
@onready var segment_results_list: VBoxContainer = $VBoxContainer/SegmentResultsList
@onready var turn_total_container: PanelContainer = $VBoxContainer/TurnTotalContainer
@onready var score_total_number: Label = $VBoxContainer/TurnTotalContainer/TotalRow/ScoreTotalNumber

## Completed turn snapshots for the current round. Each entry matches capture_segment_turn_snapshot().
var _turn_history: Array = []
var _viewed_turn_index: int = 0
var _resolving_turn: bool = false
var _score_total_counter: CountingNumber
var _punch_tweens: Dictionary = {}
var _total_style: StyleBoxFlat
## Score footer during live resolve. Grows only as each segment's Score lands.
var _live_revealed_score: int = 0

const CAMERA_SHAKE_MIN := 5.0
const CAMERA_SHAKE_MAX := 20.0
const SHAKE_DURATION := 0.42


func _ready() -> void:
	_score_total_counter = _make_stat_counter(score_total_number)
	_total_style = turn_total_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	turn_total_container.add_theme_stylebox_override("panel", _total_style)

	prev_turn_button.pressed.connect(_on_prev_turn_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)

	call_deferred("_build_segment_rows")

	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.segment_turn_completed.connect(_on_segment_turn_completed)
	EventBus.segment_score_revealed.connect(_on_segment_score_revealed)
	EventBus.segment_reveals_finished.connect(_on_segment_reveals_finished)
	EventBus.round_changed.connect(_on_round_changed)

	_refresh_view(false)
	clip_contents = false
	turn_total_container.clip_contents = false


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
	# Snap the saved turn. The live resolve already played the turn-total animation.
	_refresh_view(false)


func _on_segment_score_revealed(_segment_index: int, total_score: int) -> void:
	if not _is_viewing_live_turn():
		return
	# Footer waits until every segment row has resolved.
	_live_revealed_score += total_score


func _on_segment_reveals_finished(turn_total_score: int) -> void:
	if not _is_viewing_live_turn():
		EventBus.turn_total_count_finished.emit()
		return
	_live_revealed_score = turn_total_score
	var counter_tween := _score_total_counter.play(turn_total_score)
	var intensity := ScoreReadoutStyle.intensity_for_score(turn_total_score)
	_land_number(score_total_number, intensity)
	_pulse_panel(turn_total_container)
	_shake_screen(turn_total_score)
	ScoreBurstFx.play_background_wash(
		turn_total_container,
		ScoreReadoutStyle.intensity_for_score(turn_total_score),
		true
	)
	_finish_turn_total_animation(counter_tween)


## Turn resolve waits for the footer readout before committing the round score below.
func _finish_turn_total_animation(counter_tween: Tween) -> void:
	call_deferred("_await_turn_total_animation", counter_tween)


func _await_turn_total_animation(counter_tween: Tween) -> void:
	await _await_counter_tween(counter_tween)
	await _await_punch_tween(score_total_number)
	await _await_punch_tween(turn_total_container)
	EventBus.turn_total_count_finished.emit()


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
	turn_label.text = "TURN %d" % (_viewed_turn_index + 1)


func _update_navigation_buttons() -> void:
	prev_turn_button.disabled = _viewed_turn_index <= 0
	next_turn_button.disabled = _viewed_turn_index >= _get_latest_view_index()


func _apply_snapshot(snapshot: Dictionary, animate: bool) -> void:
	var segments: Array = snapshot.get("segments", [])
	for child in segment_results_list.get_children():
		var segment_index: int = child.segment_index
		if segment_index < 0 or segment_index >= segments.size():
			child.apply_turn_snapshot(0, 1, 0, animate)
			continue

		var segment_data: Dictionary = segments[segment_index]
		child.apply_turn_snapshot(
			int(segment_data.get("score", 0)),
			int(segment_data.get("multiplier", 1)),
			int(segment_data.get("total_score", 0)),
			animate
		)

	_update_turn_total(int(snapshot.get("total_score", 0)), animate)


func _apply_empty_snapshot(animate: bool) -> void:
	for child in segment_results_list.get_children():
		child.apply_turn_snapshot(0, 1, 0, animate)
	_update_turn_total(0, animate)


func _sync_rows_from_tile_map(animate: bool) -> void:
	var tile_map := get_tree().get_first_node_in_group("hex_map_group") as HexTileMap
	if tile_map == null:
		_apply_empty_snapshot(animate)
		return

	for child in segment_results_list.get_children():
		var segment_index: int = child.segment_index
		var score := tile_map.get_segment_turn_score(segment_index)
		var multiplier := tile_map.get_segment_turn_multiplier(segment_index)
		child.apply_turn_snapshot(score, multiplier, score * multiplier, animate, false)

	_score_total_counter.snap_to(_live_revealed_score)


func _update_turn_total(total_score: int, animate: bool) -> void:
	if animate:
		_play_counter(_score_total_counter, total_score, score_total_number)
	else:
		_score_total_counter.snap_to(total_score)


func _make_stat_counter(label: Label) -> CountingNumber:
	return CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void:
			label.text = _format_stat(as_int)
			_style_total_score(as_int)
	)


func _format_stat(value: int) -> String:
	return "-" if value == 0 else CountingNumber.format_int(value)


func _style_total_score(value: int) -> void:
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	var score_color := _themed_score_color(intensity)
	score_total_number.add_theme_color_override("font_color", score_color)
	score_total_number.add_theme_color_override(
		"font_shadow_color",
		Color(0.24, 0.16, 0.06, 0.16 + intensity * 0.16)
	)
	var digit_penalty := maxi(CountingNumber.format_int(value).length() - 8, 0)
	score_total_number.add_theme_font_size_override(
		"font_size",
		maxi(30, int(36.0 + intensity * 10.0) - digit_penalty * 2)
	)
	ScoreLandFx.refresh_text_pivot(score_total_number)
	if _total_style != null:
		_total_style.border_color = Color(score_color.r, score_color.g, score_color.b, 0.62 + intensity * 0.28)
		_total_style.shadow_color = Color(0.24, 0.16, 0.06, 0.14 + intensity * 0.12)


func _themed_score_color(intensity: float) -> Color:
	var colors: Array[Color] = [
		Color(0.2745, 0.2275, 0.1137),
		Color(0.0549, 0.3569, 0.3686),
		Color(0.72, 0.34, 0.08),
		Color(0.72, 0.16, 0.1),
	]
	var scaled := intensity * float(colors.size() - 1)
	var index := mini(int(scaled), colors.size() - 2)
	return colors[index].lerp(colors[index + 1], scaled - float(index))


func _play_counter(counter: CountingNumber, target: int, punch_target: Control) -> void:
	var tween := counter.play(target)
	if tween != null and punch_target is Label:
		var intensity := ScoreReadoutStyle.intensity_for_score(target)
		_land_number(punch_target as Label, intensity)


func _land_number(label: Label, intensity: float) -> void:
	_store_land_tween(label, ScoreLandFx.play_number_land(self, label, intensity))


func _pulse_panel(panel: Control) -> void:
	_store_land_tween(panel, ScoreLandFx.play_panel_pulse(self, panel))


func _store_land_tween(target: Control, tween: Tween) -> void:
	if target == null:
		return

	var existing: Variant = _punch_tweens.get(target)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	if tween != null:
		_punch_tweens[target] = tween


func _await_counter_tween(counter_tween: Tween) -> void:
	if counter_tween != null and counter_tween.is_valid():
		await counter_tween.finished


func _await_punch_tween(punch_target: Control) -> void:
	var punch_tween: Variant = _punch_tweens.get(punch_target)
	if punch_tween is Tween and (punch_tween as Tween).is_valid():
		await (punch_tween as Tween).finished


func _shake_screen(value: int) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	camera.shake(lerpf(CAMERA_SHAKE_MIN, CAMERA_SHAKE_MAX, intensity), SHAKE_DURATION)


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
	_disconnect_event_bus()
	if _score_total_counter != null:
		_score_total_counter.kill()


func _disconnect_event_bus() -> void:
	if EventBus.turn_ended.is_connected(_on_turn_ended):
		EventBus.turn_ended.disconnect(_on_turn_ended)
	if EventBus.segment_turn_completed.is_connected(_on_segment_turn_completed):
		EventBus.segment_turn_completed.disconnect(_on_segment_turn_completed)
	if EventBus.segment_score_revealed.is_connected(_on_segment_score_revealed):
		EventBus.segment_score_revealed.disconnect(_on_segment_score_revealed)
	if EventBus.segment_reveals_finished.is_connected(_on_segment_reveals_finished):
		EventBus.segment_reveals_finished.disconnect(_on_segment_reveals_finished)
	if EventBus.round_changed.is_connected(_on_round_changed):
		EventBus.round_changed.disconnect(_on_round_changed)
