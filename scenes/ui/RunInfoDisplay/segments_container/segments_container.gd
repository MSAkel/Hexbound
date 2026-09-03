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
@onready var round_score_footer: PanelContainer = $VBoxContainer/RoundScoreContainer

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
## Hold on the turn total before it drains into the round score below.
const TURN_TOTAL_HOLD_DELAY := 0.75


func _ready() -> void:
	_score_total_counter = _make_stat_counter(score_total_number)
	_total_style = turn_total_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	turn_total_container.add_theme_stylebox_override("panel", _total_style)

	prev_turn_button.pressed.connect(_on_prev_turn_pressed)
	next_turn_button.pressed.connect(_on_next_turn_pressed)

	call_deferred("_build_segment_rows")

	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_started.connect(_on_turn_started)
	EventBus.segment_turn_completed.connect(_on_segment_turn_completed)
	EventBus.segment_reveals_finished.connect(_on_segment_reveals_finished)
	EventBus.round_score_commit_animation_requested.connect(_on_round_score_commit_animation_requested)
	EventBus.round_changed.connect(_on_round_changed)

	_refresh_view(false)
	clip_contents = false
	turn_total_container.clip_contents = false


func _on_turn_started() -> void:
	# New turn. Show its empty row before the player ends the turn and resolve begins.
	_viewed_turn_index = _turn_history.size()
	_resolving_turn = false
	_live_revealed_score = 0
	_score_total_counter.snap_to(0)
	_style_total_score(0)
	_set_rows_live_mode(true)
	_refresh_view(false)


func _on_turn_ended() -> void:
	_resolving_turn = true
	_live_revealed_score = 0
	_score_total_counter.snap_to(0)
	_style_total_score(0)
	_viewed_turn_index = _turn_history.size()
	_set_rows_live_mode(true)
	_refresh_view(false)


func _on_segment_turn_completed(_turn_number: int, snapshot: Dictionary) -> void:
	_turn_history.append(snapshot)
	_resolving_turn = false
	# Keep the live row through the transfer drain. turn_started owns the next view.


func _on_segment_reveals_finished(turn_total_score: int) -> void:
	if not _is_viewing_live_turn():
		EventBus.turn_total_count_finished.emit()
		return
	_live_revealed_score = turn_total_score
	if GameManager.should_skip_turn_presentation():
		_snap_all_segment_scores_to_zero()
		_score_total_counter.snap_to(turn_total_score)
		score_total_number.text = _format_stat(turn_total_score)
		_style_total_score(turn_total_score)
		EventBus.turn_total_count_finished.emit()
		return
	call_deferred("_play_turn_total_transfer_animation", turn_total_score)


## Drains each segment Score to zero while the turn total counts up, then punches.
func _play_turn_total_transfer_animation(turn_total_score: int) -> void:
	if turn_total_score <= 0:
		_score_total_counter.snap_to(0)
		_style_total_score(0)
		EventBus.turn_total_count_finished.emit()
		return

	for child in segment_results_list.get_children():
		if child.has_method("play_rating_drain_to_zero"):
			child.play_rating_drain_to_zero()

	_score_total_counter.snap_to(0)
	var count_tween := _score_total_counter.play(float(turn_total_score))
	if count_tween != null:
		await _await_tween_finished(count_tween)
	else:
		_score_total_counter.snap_to(turn_total_score)
		_style_total_score(turn_total_score)

	var intensity := ScoreReadoutStyle.intensity_for_score(turn_total_score)
	AudioManager.play_sfx(UISounds.COURSE_RESULT)
	_land_number(score_total_number, intensity)
	_pulse_panel(turn_total_container)
	_shake_screen(turn_total_score)
	ScoreBurstFx.play_background_wash(
		turn_total_container,
		ScoreReadoutStyle.intensity_for_score(turn_total_score),
		true
	)
	_finish_turn_total_land_animation()


func _snap_all_segment_scores_to_zero() -> void:
	for child in segment_results_list.get_children():
		if child.has_method("snap_rating_to_zero"):
			child.snap_rating_to_zero()


func _on_round_score_commit_animation_requested(transfer_amount: int, round_score_before: int) -> void:
	if not GameManager.is_processing_turn:
		return
	call_deferred("_await_score_transfer", transfer_amount, round_score_before)


## Drains the turn total while the round score rises by the same amount.
func _await_score_transfer(transfer_amount: int, round_score_before: int) -> void:
	if transfer_amount <= 0:
		EventBus.round_score_count_finished.emit()
		return

	var turn_tween := _score_total_counter.play(0)
	var round_tween: Tween = null
	if round_score_footer.has_method("play_transfer_fill"):
		round_tween = round_score_footer.play_transfer_fill(
			round_score_before,
			round_score_before + transfer_amount
		)

	if turn_tween != null:
		await _await_tween_finished(turn_tween)
	else:
		_score_total_counter.snap_to(0)
		_style_total_score(0)

	if round_tween != null:
		await _await_tween_finished(round_tween)

	EventBus.round_score_count_finished.emit()


## Turn resolve waits for the footer punch before committing the round score below.
func _finish_turn_total_land_animation() -> void:
	call_deferred("_await_turn_total_land_animation")


func _await_turn_total_land_animation() -> void:
	await _await_punch_tween(score_total_number)
	await _await_punch_tween(turn_total_container)
	await GameManager.create_pauseable_timer(TURN_TOTAL_HOLD_DELAY / GameManager.game_speed).timeout
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
	return _turn_history.size()


func _is_viewing_current_turn() -> bool:
	return _viewed_turn_index == _turn_history.size()


func _is_viewing_live_turn() -> bool:
	return _resolving_turn and _is_viewing_current_turn()


func _set_rows_live_mode(enabled: bool) -> void:
	for child in segment_results_list.get_children():
		if child.has_method("set_accepts_live_updates"):
			child.set_accepts_live_updates(enabled)


func restore_turn_history(snapshots: Array) -> void:
	_turn_history = snapshots.duplicate(true)
	_viewed_turn_index = _turn_history.size()
	_resolving_turn = false
	_set_rows_live_mode(true)
	_refresh_view(false)


func _refresh_view(animate: bool) -> void:
	_update_turn_label()
	_update_navigation_buttons()

	if _is_viewing_live_turn():
		_set_rows_live_mode(true)
		_sync_rows_from_tile_map(animate)
		return

	if _is_viewing_current_turn():
		_set_rows_live_mode(true)
		_apply_empty_snapshot(animate)
		return

	_set_rows_live_mode(false)
	if _turn_history.is_empty():
		_apply_empty_snapshot(animate)
		return

	var snapshot: Dictionary = _turn_history[_viewed_turn_index]
	_apply_snapshot(snapshot, animate)


func _update_turn_label() -> void:
	turn_label.text = FeastDisplay.hour_label(_viewed_turn_index + 1)


func _update_navigation_buttons() -> void:
	prev_turn_button.disabled = _viewed_turn_index <= 0
	next_turn_button.disabled = _viewed_turn_index >= _get_latest_view_index()


func _apply_snapshot(snapshot: Dictionary, animate: bool) -> void:
	var segments: Array = snapshot.get("segments", [])
	for child in segment_results_list.get_children():
		var course_index: int = child.course_index
		if course_index < 0 or course_index >= segments.size():
			child.apply_turn_snapshot(0, 1, 0, animate)
			continue

		var segment_data: Dictionary = segments[course_index]
		child.apply_turn_snapshot(
			int(segment_data.get("flavour", 0)),
			float(segment_data.get("mult", 1.0)),
			int(segment_data.get("rating", 0)),
			animate
		)

	_update_turn_total(int(snapshot.get("total_rating", 0)), animate)


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
		var course_index: int = child.course_index
		var flavour := tile_map.get_segment_turn_score(course_index)
		var mult := tile_map.get_segment_turn_multiplier(course_index)
		child.apply_turn_snapshot(flavour, mult, int(round(float(flavour) * mult)), animate, false)

	# Turn total is driven by the reveal transfer beat, not live tile-map sync.
	if not _is_viewing_live_turn():
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


func _await_punch_tween(punch_target: Control) -> void:
	var punch_tween: Variant = _punch_tweens.get(punch_target)
	if punch_tween is Tween:
		await _await_tween_finished(punch_tween as Tween)


## Awaits a tween without hanging if it already finished or was killed.
## Tween.finished does not fire again after completion, and kill() never emits it.
func _await_tween_finished(tween: Tween) -> void:
	if tween == null:
		return
	while tween.is_valid():
		if tween.is_running() or get_tree().paused:
			await get_tree().process_frame
			continue
		return


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

	for course_index in tile_map.get_segment_count():
		var row: PanelContainer = SEGMENT_RESULTS_SCENE.instantiate()
		row.course_index = course_index
		segment_results_list.add_child(row)

	_set_rows_live_mode(_is_viewing_live_turn())
	var snapshots := tile_map.get_round_turn_snapshots()
	if not snapshots.is_empty():
		restore_turn_history(snapshots)
	else:
		_refresh_view(false)


func _exit_tree() -> void:
	_disconnect_event_bus()
	if _score_total_counter != null:
		_score_total_counter.kill()


func _disconnect_event_bus() -> void:
	if EventBus.turn_ended.is_connected(_on_turn_ended):
		EventBus.turn_ended.disconnect(_on_turn_ended)
	if EventBus.turn_started.is_connected(_on_turn_started):
		EventBus.turn_started.disconnect(_on_turn_started)
	if EventBus.segment_turn_completed.is_connected(_on_segment_turn_completed):
		EventBus.segment_turn_completed.disconnect(_on_segment_turn_completed)
	if EventBus.segment_reveals_finished.is_connected(_on_segment_reveals_finished):
		EventBus.segment_reveals_finished.disconnect(_on_segment_reveals_finished)
	if EventBus.round_score_commit_animation_requested.is_connected(
		_on_round_score_commit_animation_requested
	):
		EventBus.round_score_commit_animation_requested.disconnect(
			_on_round_score_commit_animation_requested
		)
	if EventBus.round_changed.is_connected(_on_round_changed):
		EventBus.round_changed.disconnect(_on_round_changed)
