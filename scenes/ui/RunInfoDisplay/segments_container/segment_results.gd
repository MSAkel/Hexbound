extends PanelContainer

## One row in the run-info panel, presented as Flavour x Mult = Rating.

var course_index: int = -1

@onready var course_no: Label = $HBoxContainer/CourseBadge/BadgeRow/CourseNo
@onready var flavour_label: Label = $HBoxContainer/FlavourContainer/CourseFlavour
@onready var mult_label: Label = $HBoxContainer/MultContainer/CourseMult
@onready var rating_container: PanelContainer = $HBoxContainer/RatingContainer
@onready var rating_label: Label = $HBoxContainer/RatingContainer/CourseRating

var _flavour: int = 0
var _additive_mult: float = 1.0
var _multiplicative_mult: float = 1.0
var _rating: int = 0
## Live resolve hides Rating until this course row's reveal beat.
var _rating_revealed: bool = true
var _accepts_live_updates: bool = true
var _flavour_counter: CountingNumber
var _mult_counter: CountingNumber
var _rating_counter: CountingNumber
var _punch_tweens: Dictionary = {}
var _row_style: StyleBoxFlat
var _rating_style: StyleBoxFlat
var _is_hovered: bool = false
var _is_revealing: bool = false
var _pulse_tween: Tween

const PUNCH_DURATION := 0.24
const ROW_PUNCH_SCALE := 1.06
const RATING_PUNCH_MIN := 1.14
const RATING_PUNCH_MAX := 1.34


func _ready() -> void:
	_row_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _row_style)
	_rating_style = rating_container.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	rating_container.add_theme_stylebox_override("panel", _rating_style)
	_flavour_counter = _make_stat_counter(flavour_label)
	_mult_counter = _make_stat_counter(mult_label)
	_rating_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void:
			rating_label.text = _format_stat(as_int)
			_apply_rating_style(as_int)
	)
	EventBus.segment_turn_results_changed.connect(_on_segment_turn_results_changed)
	EventBus.segment_turn_results_reset.connect(_on_segment_turn_results_reset)
	EventBus.segment_score_revealed.connect(_on_segment_rating_revealed)
	EventBus.segment_reveal_started.connect(_on_segment_reveal_started)
	EventBus.segment_reveal_ended.connect(_on_segment_reveal_ended)
	_set_course_no(course_index + 1)
	_sync_from_tile_map()
	clip_contents = false
	rating_container.clip_contents = false


func set_accepts_live_updates(enabled: bool) -> void:
	_accepts_live_updates = enabled
	if enabled:
		_rating_revealed = false


func apply_turn_snapshot(
	flavour: int,
	additive_mult: float,
	multiplicative_mult: float,
	rating: int,
	animate: bool = true,
	reveal_rating: bool = true
) -> void:
	if reveal_rating:
		_rating_revealed = true
	_apply_results(flavour, additive_mult, multiplicative_mult, rating, animate)


func _get_tile_map() -> HexTileMap:
	return get_tree().get_first_node_in_group("hex_map_group") as HexTileMap


func _sync_from_tile_map() -> void:
	if not _accepts_live_updates:
		return

	var tile_map := _get_tile_map()
	if tile_map == null or course_index < 0:
		_apply_results(0, 1, 1, 0, false)
		return

	var flavour := tile_map.get_segment_turn_score(course_index)
	var additive_mult := tile_map.get_segment_additive_mult(course_index)
	var multiplicative_mult := tile_map.get_segment_multiplicative_mult(course_index)
	_apply_results(flavour, additive_mult, multiplicative_mult, 0, false)


func _on_segment_turn_results_changed(
	changed_index: int,
	flavour: int,
	additive_mult: float,
	multiplicative_mult: float,
	reported_rating: int,
	_ignored_reward: int
) -> void:
	if not _accepts_live_updates or changed_index != course_index:
		return
	# After Rating starts counting, do not restart that tween. Hour resolve awaits it.
	if _is_revealing and _rating_revealed:
		_flavour = flavour
		_additive_mult = additive_mult
		_multiplicative_mult = multiplicative_mult
		_play_counter(_flavour_counter, flavour, flavour_label)
		_play_or_snap_display_mult(additive_mult, multiplicative_mult, flavour, reported_rating)
		_apply_mult_display(additive_mult, multiplicative_mult)
		return
	# Keep Rating hidden until the equals beat. Flavour and mult factors continue updating live.
	_apply_results(flavour, additive_mult, multiplicative_mult, 0)


func _on_segment_turn_results_reset() -> void:
	if not _accepts_live_updates:
		return
	_rating_revealed = false
	_apply_results(0, 1, 1, 0, false)


func _on_segment_rating_revealed(changed_index: int, rating: int) -> void:
	if changed_index != course_index:
		return
	_rating_revealed = true
	_rating = rating
	_rating_counter.snap_to(rating)
	var intensity := ScoreReadoutStyle.intensity_for_score(rating)
	_land_number(rating_label, intensity)
	_pulse_panel(rating_container)
	_punch(self, ROW_PUNCH_SCALE)
	ScoreBurstFx.play_background_wash(rating_container, intensity)
	_finish_rating_land_animation(changed_index)


## Lets hour resolve wait for the punch beat instead of a fixed timer.
func _finish_rating_land_animation(changed_index: int) -> void:
	call_deferred("_await_rating_land_animation", changed_index)


func _await_rating_land_animation(changed_index: int) -> void:
	await _await_punch_tween(rating_label)
	await _await_punch_tween(rating_container)
	await _await_punch_tween(self)
	EventBus.segment_score_count_finished.emit(changed_index)


## Counts Flavour, Mult, and Rating down to zero during the hour-total transfer beat.
func play_rating_drain_to_zero() -> Tween:
	if not _rating_revealed:
		return null

	var punch_intensity := ScoreReadoutStyle.intensity_for_score(_rating)

	_play_drain_counter(_flavour_counter, flavour_label, punch_intensity)
	var mult_tween := _play_drain_mult_counter(
		_mult_counter,
		mult_label,
		punch_intensity,
		1.0
	)
	var rating_tween := _play_drain_counter(
		_rating_counter,
		rating_label,
		punch_intensity
	)

	var finalize := func() -> void:
		_flavour = 0
		_additive_mult = 1.0
		_multiplicative_mult = 1.0
		_rating = 0
		_apply_mult_display(1.0, 1.0)

	if rating_tween != null:
		rating_tween.finished.connect(finalize, CONNECT_ONE_SHOT)
		return rating_tween
	if mult_tween != null:
		mult_tween.finished.connect(finalize, CONNECT_ONE_SHOT)
		return mult_tween

	finalize.call()
	return null


func snap_rating_to_zero() -> void:
	if not _rating_revealed:
		return
	_flavour = 0
	_additive_mult = 1.0
	_multiplicative_mult = 1.0
	_rating = 0
	_flavour_counter.snap_to(0)
	_mult_counter.snap_to(1.0)
	_rating_counter.snap_to(0)
	_apply_mult_display(1.0, 1.0)


func _on_segment_reveal_started(changed_index: int) -> void:
	if changed_index != course_index:
		_set_reveal_active(false)
		return
	_set_reveal_active(_course_has_flavour())


func _on_segment_reveal_ended() -> void:
	_set_reveal_active(false)


## Stores the latest Flavour, combined mult, and Rating, then refreshes the row labels.
func _apply_results(
	flavour: int,
	additive_mult: float,
	multiplicative_mult: float,
	rating: int,
	animate: bool = true
) -> void:
	_flavour = flavour
	_additive_mult = additive_mult
	_multiplicative_mult = multiplicative_mult
	_rating = rating

	if animate:
		_play_counter(_flavour_counter, flavour, flavour_label)
		_play_or_snap_display_mult(additive_mult, multiplicative_mult, flavour, rating)
		if _rating_revealed:
			_play_counter(_rating_counter, rating, rating_label)
		else:
			_rating_counter.snap_to(0)
	else:
		_flavour_counter.snap_to(flavour)
		_mult_counter.snap_to(float(_combined_display_mult(additive_mult, multiplicative_mult)))
		_rating_counter.snap_to(rating if _rating_revealed else 0)
	_apply_mult_display(additive_mult, multiplicative_mult)


func _combined_display_mult(additive_mult: float, multiplicative_mult: float) -> int:
	return CountingNumber.combined_display_mult(additive_mult, multiplicative_mult)


func _play_or_snap_display_mult(
	additive_mult: float,
	multiplicative_mult: float,
	flavour: int,
	rating: int
) -> void:
	var display_mult := float(_combined_display_mult(additive_mult, multiplicative_mult))
	if _is_idle_display_mult(additive_mult, multiplicative_mult, flavour, rating):
		_mult_counter.snap_to(display_mult)
	else:
		_play_counter(_mult_counter, display_mult, mult_label)


func _make_stat_counter(label: Label) -> CountingNumber:
	return CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: label.text = _format_stat(as_int)
	)


func _format_stat(value: int) -> String:
	return "-" if value == 0 else CountingNumber.format_int(value)


func _is_idle_display_mult(
	additive_mult: float,
	multiplicative_mult: float,
	flavour: int,
	rating: int
) -> bool:
	return (
		_combined_display_mult(additive_mult, multiplicative_mult) <= 1
		and flavour == 0
		and rating == 0
	)


func _apply_mult_display(additive_mult: float, multiplicative_mult: float) -> void:
	var has_activity := _flavour > 0 or _rating > 0
	var display_mult := _combined_display_mult(additive_mult, multiplicative_mult)
	if _is_idle_display_mult(
		additive_mult,
		multiplicative_mult,
		_flavour if has_activity else 0,
		_rating if has_activity else 0
	):
		mult_label.text = "-"
	else:
		mult_label.text = CountingNumber.format_int(display_mult)


func _apply_rating_style(value: int) -> void:
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	var rating_color := _themed_rating_color(intensity)
	rating_label.add_theme_color_override("font_color", rating_color)
	rating_label.add_theme_color_override(
		"font_shadow_color",
		Color(0.24, 0.16, 0.06, 0.14 + intensity * 0.16)
	)
	var digit_penalty := maxi(CountingNumber.format_int(value).length() - 7, 0)
	rating_label.add_theme_font_size_override(
		"font_size",
		maxi(18, int(22.0 + intensity * 5.0) - digit_penalty * 2)
	)
	if _rating_style != null:
		var rating_tint := rating_color.lightened(0.72)
		_rating_style.bg_color = Color(0.98, 0.945, 0.84, 0.96).lerp(
			Color(rating_tint.r, rating_tint.g, rating_tint.b, 0.96),
			intensity * 0.28
		)
		_rating_style.border_color = Color(rating_color.r, rating_color.g, rating_color.b, 0.46 + intensity * 0.42)
		_rating_style.shadow_color = Color(0.24, 0.16, 0.06, 0.12 + intensity * 0.12)
	_apply_row_style(intensity, rating_color)


func _themed_rating_color(intensity: float) -> Color:
	var colors: Array[Color] = [
		Color(0.2745, 0.2275, 0.1137),
		Color(0.0549, 0.3569, 0.3686),
		Color(0.72, 0.34, 0.08),
		Color(0.72, 0.16, 0.1),
	]
	var scaled := intensity * float(colors.size() - 1)
	var index := mini(int(scaled), colors.size() - 2)
	return colors[index].lerp(colors[index + 1], scaled - float(index))


func _apply_row_style(intensity: float, rating_color: Color) -> void:
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
		lerpf(lerpf(0.545, rating_color.r, intensity), 1.0, reveal_amount * 0.72),
		lerpf(lerpf(0.431, rating_color.g, intensity), 0.78, reveal_amount * 0.72),
		lerpf(lerpf(0.243, rating_color.b, intensity), 0.22, reveal_amount * 0.72),
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
		var punch_scale := lerpf(RATING_PUNCH_MIN, RATING_PUNCH_MAX, intensity)
		if punch_target != rating_label:
			punch_scale = lerpf(1.08, 1.16, intensity)
		_punch(punch_target, punch_scale)


func _play_drain_mult_counter(
	counter: CountingNumber,
	punch_target: Control,
	punch_intensity: float,
	target: float
) -> Tween:
	var tween := counter.play(target)
	if tween == null:
		counter.snap_to(target)
	var punch_scale := lerpf(RATING_PUNCH_MIN, RATING_PUNCH_MAX, punch_intensity)
	if punch_target != rating_label:
		punch_scale = lerpf(1.08, 1.16, punch_intensity)
	_punch(punch_target, punch_scale)
	return tween


func _play_drain_counter(
	counter: CountingNumber,
	punch_target: Control,
	punch_intensity: float
) -> Tween:
	var tween := counter.play(0.0)
	if tween == null:
		counter.snap_to(0.0)
	var punch_scale := lerpf(RATING_PUNCH_MIN, RATING_PUNCH_MAX, punch_intensity)
	if punch_target != rating_label:
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


func _course_has_flavour() -> bool:
	if _flavour > 0:
		return true
	var tile_map := _get_tile_map()
	if tile_map == null or course_index < 0:
		return false
	return tile_map.get_segment_turn_score(course_index) > 0


func _set_reveal_active(active: bool) -> void:
	if _is_revealing == active:
		return
	_is_revealing = active
	_apply_rating_style(_rating if _rating_revealed else 0)
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
		_pulse_tween = null
	if not active:
		modulate = Color.WHITE
		return

	# Pulse while this row matches the glowing map course.
	var pulse := 0.2 / GameManager.game_speed
	_pulse_tween = create_tween()
	_pulse_tween.set_loops()
	_pulse_tween.tween_property(self, "modulate", Color(1.16, 1.08, 0.88, 1.0), pulse).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_IN_OUT)
	_pulse_tween.tween_property(self, "modulate", Color.WHITE, pulse).set_trans(Tween.TRANS_SINE).set_ease(
		Tween.EASE_IN_OUT
	)


func _set_course_no(no: int) -> void:
	if no <= 0:
		course_no.text = "-"
		return
	course_no.text = "%02d" % no


func _on_mouse_entered() -> void:
	_is_hovered = true
	_apply_rating_style(_rating if _rating_revealed else 0)
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.highlight_hovered_segment(course_index)


func _on_mouse_exited() -> void:
	_is_hovered = false
	_apply_rating_style(_rating if _rating_revealed else 0)
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(course_index)


func _exit_tree() -> void:
	_disconnect_event_bus()
	if _flavour_counter != null:
		_flavour_counter.kill()
	if _mult_counter != null:
		_mult_counter.kill()
	if _rating_counter != null:
		_rating_counter.kill()
	if _pulse_tween != null and _pulse_tween.is_valid():
		_pulse_tween.kill()
	var tile_map := _get_tile_map()
	if tile_map != null:
		tile_map.clear_hovered_segment_highlight(course_index)


func _disconnect_event_bus() -> void:
	if EventBus.segment_turn_results_changed.is_connected(_on_segment_turn_results_changed):
		EventBus.segment_turn_results_changed.disconnect(_on_segment_turn_results_changed)
	if EventBus.segment_turn_results_reset.is_connected(_on_segment_turn_results_reset):
		EventBus.segment_turn_results_reset.disconnect(_on_segment_turn_results_reset)
	if EventBus.segment_score_revealed.is_connected(_on_segment_rating_revealed):
		EventBus.segment_score_revealed.disconnect(_on_segment_rating_revealed)
	if EventBus.segment_reveal_started.is_connected(_on_segment_reveal_started):
		EventBus.segment_reveal_started.disconnect(_on_segment_reveal_started)
	if EventBus.segment_reveal_ended.is_connected(_on_segment_reveal_ended):
		EventBus.segment_reveal_ended.disconnect(_on_segment_reveal_ended)
