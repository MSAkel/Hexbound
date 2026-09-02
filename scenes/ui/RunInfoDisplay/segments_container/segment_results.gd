extends PanelContainer

## One row in the run-info panel, presented as Energy x Multiplier = Score.

var segment_index: int = -1

@onready var segment_no: Label = $HBoxContainer/SegmentBadge/BadgeRow/SegmentNo
@onready var segment_power: Label = $HBoxContainer/EnergyContainer/SegmentPower
@onready var segment_multiplier: Label = $HBoxContainer/MultiplierContainer/SegmentMultiplier
@onready var score_container: PanelContainer = $HBoxContainer/ScoreContainer
@onready var segment_total_score: Label = $HBoxContainer/ScoreContainer/SegmentTotalScore

var _score: int = 0
var _multiplier: float = 1.0
var _total_score: int = 0
## Live resolve hides Score until this segment's reveal beat.
var _score_revealed: bool = true
var _accepts_live_updates: bool = true
var _power_counter: CountingNumber
var _multiplier_counter: CountingNumber
var _total_score_counter: CountingNumber
var _punch_tweens: Dictionary = {}
var _row_style: StyleBoxFlat
var _score_style: StyleBoxFlat
var _is_hovered: bool = false
var _is_revealing: bool = false
var _pulse_tween: Tween

const PUNCH_DURATION := 0.24
const ROW_PUNCH_SCALE := 1.06
const SCORE_PUNCH_MIN := 1.14
const SCORE_PUNCH_MAX := 1.34


func _ready() -> void:
	_row_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _row_style)
	_score_style = score_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	score_container.add_theme_stylebox_override("panel", _score_style)
	_power_counter = _make_stat_counter(segment_power)
	_multiplier_counter = CountingNumber.new(
		self,
		func(text: String) -> void: segment_multiplier.text = text
	)
	_multiplier_counter.set_format_as_mult(true)
	_total_score_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void:
			segment_total_score.text = _format_stat(as_int)
			_apply_score_style(as_int)
	)
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	EventBus.segment_score_revealed.connect(_on_segment_score_revealed)
	EventBus.segment_reveal_started.connect(_on_segment_reveal_started)
	EventBus.segment_reveal_ended.connect(_on_segment_reveal_ended)
	_set_segment_no(segment_index + 1)
	_sync_from_tile_map()
	clip_contents = false
	score_container.clip_contents = false


func set_accepts_live_updates(enabled: bool) -> void:
	_accepts_live_updates = enabled
	if enabled:
		_score_revealed = false


func apply_turn_snapshot(
	score: int,
	multiplier: float,
	total_score: int,
	animate: bool = true,
	reveal_score: bool = true
) -> void:
	if reveal_score:
		_score_revealed = true
	_apply_results(score, multiplier, total_score, animate)


func _get_tile_map() -> HexTileMap:
	return get_tree().get_first_node_in_group("hex_map_group") as HexTileMap


func _sync_from_tile_map() -> void:
	if not _accepts_live_updates:
		return

	var tile_map := _get_tile_map()
	if tile_map == null or segment_index < 0:
		_apply_results(0, 1, 0, false)
		return

	var score := tile_map.get_segment_turn_score(segment_index)
	var multiplier := tile_map.get_segment_turn_multiplier(segment_index)
	_apply_results(score, multiplier, 0, false)


func _on_segment_turn_results_changed(
	changed_index: int,
	score: int,
	multiplier: float,
	reported_total_score: int,
	_ignored_reward: int
) -> void:
	if not _accepts_live_updates or changed_index != segment_index:
		return
	# After Score starts counting, do not restart that tween. Turn resolve awaits it.
	if _is_revealing and _score_revealed:
		_score = score
		_multiplier = multiplier
		_play_counter(_power_counter, score, segment_power)
		var idle_mult := multiplier <= 1.0 + 0.0001 and score == 0 and reported_total_score == 0
		if idle_mult:
			_multiplier_counter.snap_to(multiplier)
		else:
			_play_counter(_multiplier_counter, multiplier, segment_multiplier)
		_apply_multiplier_display(multiplier)
		return
	# Keep Score hidden until the equals beat. Factors continue updating live.
	_apply_results(score, multiplier, 0)


func _on_segment_turn_results_reset() -> void:
	if not _accepts_live_updates:
		return
	_score_revealed = false
	_apply_results(0, 1, 0, false)


func _on_segment_score_revealed(changed_index: int, total_score: int) -> void:
	if changed_index != segment_index:
		return
	_score_revealed = true
	_total_score = total_score
	_total_score_counter.snap_to(total_score)
	var intensity := ScoreReadoutStyle.intensity_for_score(total_score)
	_land_number(segment_total_score, intensity)
	_pulse_panel(score_container)
	_punch(self, ROW_PUNCH_SCALE)
	ScoreBurstFx.play_background_wash(score_container, intensity)
	_finish_segment_score_land_animation(changed_index)


## Lets turn resolve wait for the punch beat instead of a fixed timer.
func _finish_segment_score_land_animation(changed_index: int) -> void:
	call_deferred("_await_segment_score_land_animation", changed_index)


func _await_segment_score_land_animation(changed_index: int) -> void:
	await _await_punch_tween(segment_total_score)
	await _await_punch_tween(score_container)
	await _await_punch_tween(self)
	EventBus.segment_score_count_finished.emit(changed_index)


## Counts Energy, Mult, and Score down to zero during the turn-total transfer beat.
func play_score_drain_to_zero() -> Tween:
	if not _score_revealed:
		return null

	var punch_intensity := ScoreReadoutStyle.intensity_for_score(_total_score)

	_play_drain_counter(_power_counter, segment_power, punch_intensity)
	_play_drain_counter(_multiplier_counter, segment_multiplier, punch_intensity)
	var score_tween := _play_drain_counter(
		_total_score_counter,
		segment_total_score,
		punch_intensity
	)

	var finalize := func() -> void:
		_score = 0
		_multiplier = 0.0
		_total_score = 0
		_apply_multiplier_display(0.0)

	if score_tween != null:
		score_tween.finished.connect(finalize, CONNECT_ONE_SHOT)
		return score_tween

	finalize.call()
	return null


func snap_score_to_zero() -> void:
	if not _score_revealed:
		return
	_score = 0
	_multiplier = 0.0
	_total_score = 0
	_power_counter.snap_to(0)
	_multiplier_counter.snap_to(0)
	_total_score_counter.snap_to(0)
	_apply_multiplier_display(0.0)


func _on_segment_reveal_started(changed_index: int) -> void:
	if changed_index != segment_index:
		_set_reveal_active(false)
		return
	_set_reveal_active(_segment_has_power())


func _on_segment_reveal_ended() -> void:
	_set_reveal_active(false)


## Stores the latest factors and payoff, then refreshes the row labels.
func _apply_results(
	score: int,
	multiplier: float,
	total_score: int,
	animate: bool = true
) -> void:
	_score = score
	_multiplier = multiplier
	_total_score = total_score

	if animate:
		_play_counter(_power_counter, score, segment_power)
		var idle_mult := multiplier <= 1.0 + 0.0001 and score == 0 and total_score == 0
		if idle_mult:
			_multiplier_counter.snap_to(multiplier)
		else:
			_play_counter(_multiplier_counter, multiplier, segment_multiplier)
		if _score_revealed:
			_play_counter(_total_score_counter, total_score, segment_total_score)
		else:
			_total_score_counter.snap_to(0)
	else:
		_power_counter.snap_to(score)
		_multiplier_counter.snap_to(multiplier)
		_total_score_counter.snap_to(total_score if _score_revealed else 0)
	_apply_multiplier_display(multiplier)


func _make_stat_counter(label: Label) -> CountingNumber:
	return CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: label.text = _format_stat(as_int)
	)


func _format_stat(value: int) -> String:
	return "-" if value == 0 else CountingNumber.format_int(value)


func _apply_multiplier_display(multiplier: float) -> void:
	var has_activity := _score > 0 or _total_score > 0
	if multiplier <= 1.0 + 0.0001 and not has_activity:
		segment_multiplier.text = "-"
	else:
		segment_multiplier.text = CountingNumber.format_mult(multiplier)


func _apply_score_style(value: int) -> void:
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	var score_color := _themed_score_color(intensity)
	segment_total_score.add_theme_color_override("font_color", score_color)
	segment_total_score.add_theme_color_override(
		"font_shadow_color",
		Color(0.24, 0.16, 0.06, 0.14 + intensity * 0.16)
	)
	var digit_penalty := maxi(CountingNumber.format_int(value).length() - 7, 0)
	segment_total_score.add_theme_font_size_override(
		"font_size",
		maxi(18, int(22.0 + intensity * 5.0) - digit_penalty * 2)
	)
	if _score_style != null:
		var score_tint := score_color.lightened(0.72)
		_score_style.bg_color = Color(0.98, 0.945, 0.84, 0.96).lerp(
			Color(score_tint.r, score_tint.g, score_tint.b, 0.96),
			intensity * 0.28
		)
		_score_style.border_color = Color(score_color.r, score_color.g, score_color.b, 0.46 + intensity * 0.42)
		_score_style.shadow_color = Color(0.24, 0.16, 0.06, 0.12 + intensity * 0.12)
	_apply_row_style(intensity, score_color)


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


func _apply_row_style(intensity: float, score_color: Color) -> void:
	if _row_style == null:
		return
	var hover_amount := 1.0 if _is_hovered else 0.0
	var reveal_amount := 1.0 if _is_revealing else 0.0
	_row_style.bg_color = Color(
		0.94 + hover_amount * 0.035 + reveal_amount * 0.05,
		0.885 + hover_amount * 0.035 + reveal_amount * 0.02,
		0.73 + hover_amount * 0.055 - reveal_amount * 0.08,
		0.86 + reveal_amount * 0.08
	)
	_row_style.border_color = Color(
		lerpf(lerpf(0.545, score_color.r, intensity), 1.0, reveal_amount * 0.72),
		lerpf(lerpf(0.431, score_color.g, intensity), 0.78, reveal_amount * 0.72),
		lerpf(lerpf(0.243, score_color.b, intensity), 0.22, reveal_amount * 0.72),
		0.48 + intensity * 0.35 + hover_amount * 0.12 + reveal_amount * 0.4
	)
	_row_style.border_width_left = 4 if _is_revealing else 2
	_row_style.shadow_size = 4 if _is_revealing else 0
	_row_style.shadow_color = Color(1.0, 0.72, 0.2, 0.35 if _is_revealing else 0.0)


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


func _play_counter(counter: CountingNumber, target: float, punch_target: Control) -> void:
	var tween := counter.play(target)
	if tween != null:
		var intensity := ScoreReadoutStyle.intensity_for_score(int(round(target)))
		var punch_scale := lerpf(SCORE_PUNCH_MIN, SCORE_PUNCH_MAX, intensity)
		if punch_target != segment_total_score:
			punch_scale = lerpf(1.08, 1.16, intensity)
		_punch(punch_target, punch_scale)


func _play_drain_counter(
	counter: CountingNumber,
	punch_target: Control,
	punch_intensity: float
) -> Tween:
	var tween := counter.play(0.0)
	if tween == null:
		counter.snap_to(0.0)
	var punch_scale := lerpf(SCORE_PUNCH_MIN, SCORE_PUNCH_MAX, punch_intensity)
	if punch_target != segment_total_score:
		punch_scale = lerpf(1.08, 1.16, punch_intensity)
	_punch(punch_target, punch_scale)
	return tween


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


func _punch(control: Control, punch_scale: float) -> void:
	if control == null:
		return

	var existing: Variant = _punch_tweens.get(control)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	control.pivot_offset = control.size * 0.5
	control.scale = Vector2.ONE

	var duration := PUNCH_DURATION / GameManager.game_speed
	var tween := create_tween()
	tween.tween_property(control, "scale", Vector2(punch_scale, punch_scale), duration * 0.4).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "scale", Vector2.ONE, duration * 0.6).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	_punch_tweens[control] = tween


func _segment_has_power() -> bool:
	if _score > 0:
		return true
	var tile_map := _get_tile_map()
	if tile_map == null or segment_index < 0:
		return false
	return tile_map.get_segment_turn_score(segment_index) > 0


func _set_reveal_active(active: bool) -> void:
	if _is_revealing == active:
		return
	_is_revealing = active
	_apply_score_style(_total_score if _score_revealed else 0)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if not active:
		modulate = Color.WHITE
		return

	# Pulse while this row matches the glowing map segment.
	var pulse := 0.2 / GameManager.game_speed
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "modulate", Color(1.16, 1.08, 0.88, 1.0), pulse).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, pulse).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func _set_segment_no(no: int) -> void:
	if no <= 0:
		segment_no.text = "-"
		return
	segment_no.text = "%02d" % no


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_score_style(_total_score if _score_revealed else 0)
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.highlight_hovered_segment(segment_index)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_score_style(_total_score if _score_revealed else 0)
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(segment_index)


func _exit_tree() -> void:
	_disconnect_event_bus()
	if _power_counter != null:
		_power_counter.kill()
	if _multiplier_counter != null:
		_multiplier_counter.kill()
	if _total_score_counter != null:
		_total_score_counter.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(segment_index)


func _disconnect_event_bus() -> void:
	if EventBus.segment_turn_results_changed.is_connected(_on_segment_turn_results_changed):
		EventBus.segment_turn_results_changed.disconnect(_on_segment_turn_results_changed)
	if EventBus.segment_turn_results_reset.is_connected(_on_segment_turn_results_reset):
		EventBus.segment_turn_results_reset.disconnect(_on_segment_turn_results_reset)
	if EventBus.segment_score_revealed.is_connected(_on_segment_score_revealed):
		EventBus.segment_score_revealed.disconnect(_on_segment_score_revealed)
	if EventBus.segment_reveal_started.is_connected(_on_segment_reveal_started):
		EventBus.segment_reveal_started.disconnect(_on_segment_reveal_started)
	if EventBus.segment_reveal_ended.is_connected(_on_segment_reveal_ended):
		EventBus.segment_reveal_ended.disconnect(_on_segment_reveal_ended)
