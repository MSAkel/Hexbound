extends PanelContainer

## Round score footer. Hero number on the right, target shown as a quiet subtitle on the left.

@onready var target_label: Label = $TotalRow/TotalCopy/TargetLabel
@onready var score_this_round: Label = $TotalRow/ScoreThisRound

var _round_score_counter: CountingNumber
var _target_counter: CountingNumber
var _panel_style: StyleBoxFlat
var _land_tweens: Dictionary = {}


func _ready() -> void:
	_panel_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _panel_style)

	_round_score_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		true,
		_on_round_score_counted
	)
	_target_counter = CountingNumber.new(
		self,
		func(text: String) -> void: target_label.text = "TARGET %s" % text,
		true
	)

	_round_score_counter.snap_to(GameManager.total_round_score)
	_target_counter.snap_to(GameManager.required_score)

	EventBus.total_round_score_changed.connect(_on_total_round_score_changed)
	EventBus.round_score_commit_animation_requested.connect(_on_round_score_commit_animation_requested)
	EventBus.required_score_changed.connect(_on_required_score_changed)

	clip_contents = false


func _on_total_round_score_changed() -> void:
	# Turn resolve plays the round score only after the segment turn total finishes.
	if GameManager.is_processing_turn:
		return
	_play_round_score_counter()


func _on_round_score_commit_animation_requested() -> void:
	_play_round_score_counter()


## Round score lands after the turn total, then round flow can continue.
func _play_round_score_counter() -> void:
	call_deferred("_await_round_score_counter")


func _await_round_score_counter() -> void:
	var counter_tween := _round_score_counter.play(GameManager.total_round_score)
	var intensity := ScoreReadoutStyle.intensity_for_score(GameManager.total_round_score)
	_land_number(score_this_round, intensity)
	_pulse_panel(self)
	ScoreBurstFx.play_background_wash(self, intensity, true)
	await _await_counter_tween(counter_tween)
	await _await_land_tween(score_this_round)
	await _await_land_tween(self)
	# Only gate turn resolve. Other score updates still animate normally.
	if GameManager.is_processing_turn:
		EventBus.round_score_count_finished.emit()


func _on_required_score_changed() -> void:
	_target_counter.snap_to(GameManager.required_score)


func _on_round_score_counted(as_int: int) -> void:
	score_this_round.text = CountingNumber.format_int(as_int)
	_style_round_score(as_int)


func _style_round_score(value: int) -> void:
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	var score_color := _themed_score_color(intensity)
	score_this_round.add_theme_color_override("font_color", score_color)
	score_this_round.add_theme_color_override(
		"font_shadow_color",
		Color(0.24, 0.16, 0.06, 0.16 + intensity * 0.16)
	)
	var digit_penalty := maxi(CountingNumber.format_int(value).length() - 8, 0)
	score_this_round.add_theme_font_size_override(
		"font_size",
		maxi(30, int(36.0 + intensity * 10.0) - digit_penalty * 2)
	)
	ScoreLandFx.refresh_text_pivot(score_this_round)
	if _panel_style != null:
		_panel_style.border_color = Color(score_color.r, score_color.g, score_color.b, 0.62 + intensity * 0.28)
		_panel_style.shadow_color = Color(0.24, 0.16, 0.06, 0.14 + intensity * 0.12)


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


func _land_number(label: Label, intensity: float) -> void:
	_store_land_tween(label, ScoreLandFx.play_number_land(self, label, intensity))


func _pulse_panel(panel: Control) -> void:
	_store_land_tween(panel, ScoreLandFx.play_panel_pulse(self, panel))


func _store_land_tween(target: Control, tween: Tween) -> void:
	if target == null:
		return

	var existing: Variant = _land_tweens.get(target)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()

	if tween != null:
		_land_tweens[target] = tween


func _await_counter_tween(counter_tween: Tween) -> void:
	await _await_tween_finished(counter_tween)


func _await_land_tween(land_target: Control) -> void:
	var land_tween: Variant = _land_tweens.get(land_target)
	if land_tween is Tween:
		await _await_tween_finished(land_tween as Tween)


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


func _exit_tree() -> void:
	if _round_score_counter != null:
		_round_score_counter.kill()
	if _target_counter != null:
		_target_counter.kill()
