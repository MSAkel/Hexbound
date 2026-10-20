class_name HourScoreReadout
extends Control

## Top-center Flavour x Mult readout shown while an Hour resolves.
## Score floats fly in and bump the numbers. Once every trigger is done the pair merges
## into the Hour score, which then flies into the Day Rating panel.

enum Product { NONE = -1, FLAVOUR = 0, MULT = 1 }

const GROUP := "hour_score_readout"

const SHOW_DURATION := 0.22
const HIDE_DURATION := 0.18
## Longest wait for floats still flying when the merge is requested.
const IN_FLIGHT_WAIT_CAP := 1.2

const GAIN_SQUASH := Vector2(1.38, 0.78)
const GAIN_STRETCH := Vector2(0.9, 1.22)
const GAIN_HIT := 0.06
const GAIN_REBOUND := 0.07
const GAIN_SETTLE := 0.38
const GAIN_TILT_MIN_DEG := 3.0
const GAIN_TILT_MAX_DEG := 9.0

const MERGE_ANTICIPATION := 0.12
const MERGE_DURATION := 0.26
const TOTAL_POP_DURATION := 0.2
const TOTAL_SETTLE_DURATION := 0.35
const TOTAL_POP_SCALE := 1.28
const TOTAL_MIN_FONT_SIZE := 52
const TOTAL_MAX_FONT_SIZE := 124
## Hold on the merged score before the turn moves on to commit it.
const TOTAL_HOLD := 0.25

const FLY_DURATION := 0.46
const FLY_END_SCALE := 0.4

const CAMERA_SHAKE_MIN := 4.0
const CAMERA_SHAKE_MAX := 20.0
const SHAKE_DURATION := 0.42

## Day Rating panel the merged score flies into.
@export var day_rating_panel: DayRatingPanel

@onready var formula: HBoxContainer = $Formula
@onready var flavour_label: Label = $Formula/FlavourLabel
@onready var times_label: Label = $Formula/TimesLabel
@onready var mult_label: Label = $Formula/MultLabel
@onready var total_label: Label = $TotalLabel

var _accepting := false
## Latest Hour values from the tile map. Floats reserve these as they spawn.
var _target_flavour := 0
var _target_mult := 1
## Per product: ticket -> value that ticket shows when its float lands.
var _pending: Array[Dictionary] = [{}, {}]
var _last_applied_ticket: Array[int] = [-1, -1]
var _next_ticket := 0
var _shown_values: Array[int] = [0, 1]

var _flavour_counter: CountingNumber
var _mult_counter: CountingNumber
var _total_counter: CountingNumber
var _fade_tween: Tween
var _fx_tweens: Dictionary = {}


## The readout currently taking score floats, or null outside a presented resolve.
static func find_accepting(tree: SceneTree) -> HourScoreReadout:
	if tree == null:
		return null
	var readout := tree.get_first_node_in_group(GROUP) as HourScoreReadout
	if readout == null or not readout.is_accepting():
		return null
	return readout


## Which readout number a floating text payout feeds, read from its stat icon.
static func product_for_float(icon: Texture2D, target_icon: Texture2D) -> Product:
	if icon == null or target_icon != null:
		return Product.NONE
	if icon == TileCard.ICON_FLAVOUR:
		return Product.FLAVOUR
	if icon == TileCard.ICON_MULT:
		return Product.MULT
	return Product.NONE


func _ready() -> void:
	add_to_group(GROUP)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	for control: Control in [flavour_label, times_label, mult_label, total_label]:
		_keep_pivot_centered(control)

	_flavour_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: flavour_label.text = _format_flavour(as_int)
	)
	_mult_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: mult_label.text = CountingNumber.format_int(maxi(1, as_int))
	)
	_total_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		func(as_int: int) -> void: total_label.text = CountingNumber.format_int(as_int)
	)

	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.hour_results_reset.connect(_on_hour_results_reset)
	EventBus.hour_results_changed.connect(_on_hour_results_changed)
	EventBus.hour_score_presentation_requested.connect(_on_hour_score_presentation_requested)
	EventBus.round_score_commit_animation_requested.connect(_on_round_score_commit_animation_requested)

	_reset_display()
	visible = false
	modulate.a = 0.0


func is_accepting() -> bool:
	return _accepting


## Reserves the current Hour value for a float that will land later.
func reserve(product: int) -> int:
	var ticket := _next_ticket
	_next_ticket += 1
	_pending[product][ticket] = _target_value(product)
	return ticket


## Screen-space point a float should fly to for this product.
func get_absorb_point(product: int) -> Vector2:
	var label := flavour_label if product == Product.FLAVOUR else mult_label
	return label.get_global_rect().get_center()


## A float landed. Shows the value it reserved unless a later float already landed.
func absorb(product: int, ticket: int) -> void:
	if not _pending[product].has(ticket):
		return
	var value: int = _pending[product][ticket]
	_pending[product].erase(ticket)
	if not _accepting or ticket < _last_applied_ticket[product]:
		return
	_last_applied_ticket[product] = ticket
	_show_value(product, value)


## Float was freed before landing.
func cancel(product: int, ticket: int) -> void:
	if product == Product.FLAVOUR or product == Product.MULT:
		_pending[product].erase(ticket)


func _target_value(product: int) -> int:
	return _target_flavour if product == Product.FLAVOUR else _target_mult


func _has_floats_in_flight() -> bool:
	return not _pending[Product.FLAVOUR].is_empty() or not _pending[Product.MULT].is_empty()


#region Hour lifecycle

func _on_turn_ended() -> void:
	if GameManager.skip_presentation:
		return
	_reset_display()
	_accepting = true
	_fade_to(true)


func _on_hour_results_reset() -> void:
	_target_flavour = 0
	_target_mult = 1
	if _accepting:
		_reset_display()


func _on_hour_results_changed(_segment_index: int, flavour: int, mult: float, _gold: int) -> void:
	_target_flavour = flavour
	_target_mult = CountingNumber.combined_display_mult(mult, 1.0)


func _reset_display() -> void:
	_kill_fx()
	for ticket_values: Dictionary in _pending:
		ticket_values.clear()
	_last_applied_ticket = [-1, -1]
	_shown_values = [0, 1]
	_flavour_counter.snap_to(0)
	_mult_counter.snap_to(1)
	_total_counter.snap_to(0)
	for control: Control in [formula, flavour_label, times_label, mult_label]:
		control.scale = Vector2.ONE
		control.rotation_degrees = 0.0
		control.modulate = Color.WHITE
	formula.visible = true
	formula.queue_sort()
	total_label.visible = false
	total_label.scale = Vector2.ONE
	total_label.modulate = Color.WHITE
	_center_total_label()


func _fade_to(shown: bool) -> Tween:
	if _fade_tween != null and _fade_tween.is_valid():
		_fade_tween.kill()
	if shown:
		visible = true
		pivot_offset = size * 0.5
		scale = Vector2(0.85, 0.85)
	var duration := (SHOW_DURATION if shown else HIDE_DURATION) / GameManager.game_speed
	_fade_tween = create_tween()
	_fade_tween.set_parallel(true)
	_fade_tween.tween_property(self, "modulate:a", 1.0 if shown else 0.0, duration)
	_fade_tween.tween_property(self, "scale", Vector2.ONE, duration).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	if not shown:
		_fade_tween.chain().tween_callback(func() -> void: visible = false)
	return _fade_tween

#endregion


#region Per-trigger gains

func _show_value(product: int, value: int) -> void:
	var previous := _shown_values[product]
	if value == previous:
		return
	_shown_values[product] = value
	var counter := _flavour_counter if product == Product.FLAVOUR else _mult_counter
	var label := flavour_label if product == Product.FLAVOUR else mult_label
	counter.play(value)
	var strength := clampf(0.4 + log(1.0 + absf(value - previous)) / log(1000.0) * 0.6, 0.4, 1.0)
	_play_gain_fx(label, strength)


## Squash, stretch, and tilt. strength is 0 to 1.
func _play_gain_fx(control: Control, strength: float) -> void:
	var speed := GameManager.game_speed
	var squash := Vector2.ONE.lerp(GAIN_SQUASH, strength)
	var stretch := Vector2.ONE.lerp(GAIN_STRETCH, strength)
	var tilt := lerpf(GAIN_TILT_MIN_DEG, GAIN_TILT_MAX_DEG, strength) * (-1.0 if randf() > 0.5 else 1.0)

	control.scale = Vector2.ONE
	control.rotation_degrees = 0.0
	var tween := _replace_fx_tween(control)
	tween.set_parallel(true)
	tween.tween_property(control, "scale", squash, GAIN_HIT / speed).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.tween_property(control, "rotation_degrees", tilt, GAIN_HIT / speed)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", stretch, GAIN_REBOUND / speed).set_trans(Tween.TRANS_QUAD).set_ease(
		Tween.EASE_OUT
	)
	tween.chain()
	tween.set_parallel(true)
	tween.tween_property(control, "scale", Vector2.ONE, GAIN_SETTLE / speed).set_trans(
		Tween.TRANS_ELASTIC
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(control, "rotation_degrees", 0.0, GAIN_SETTLE / speed).set_trans(
		Tween.TRANS_ELASTIC
	).set_ease(Tween.EASE_OUT)


#endregion


#region Merge into the Hour score

func _on_hour_score_presentation_requested(flavour: int, mult: float, score: int) -> void:
	_present_score(flavour, CountingNumber.combined_display_mult(mult, 1.0), score)


func _present_score(flavour: int, mult: int, score: int) -> void:
	if not visible:
		_reset_display()
		_fade_to(true)
	await _wait_for_floats_in_flight()
	_accepting = false

	# Catch payouts that changed the Hour without a float of their own.
	_show_value(Product.FLAVOUR, flavour)
	_show_value(Product.MULT, mult)

	if score <= 0 or flavour <= 0:
		await _hold(TOTAL_HOLD * 0.5)
		await TweenWait.finished(self, _fade_to(false))
		EventBus.hour_score_presentation_finished.emit()
		return

	await _hold(0.18)
	await _play_merge()
	await _play_total_pop(score)
	await _hold(TOTAL_HOLD)
	EventBus.hour_score_presentation_finished.emit()


func _wait_for_floats_in_flight() -> void:
	var timer := GameManager.create_pauseable_timer(IN_FLIGHT_WAIT_CAP / GameManager.game_speed)
	while _has_floats_in_flight() and timer.time_left > 0.0 and is_inside_tree():
		await get_tree().process_frame


func _hold(seconds: float) -> void:
	await GameManager.create_pauseable_timer(seconds / GameManager.game_speed).timeout


## Flavour and Mult rush into the x while it swells and shrinks away.
func _play_merge() -> void:
	_kill_fx()
	# Settle the counts and let the row sort once, so no text change re-sorts it mid-merge.
	_flavour_counter.snap_to(_shown_values[Product.FLAVOUR])
	_mult_counter.snap_to(_shown_values[Product.MULT])
	for control: Control in [flavour_label, times_label, mult_label]:
		control.scale = Vector2.ONE
		control.rotation_degrees = 0.0
		control.modulate = Color.WHITE
	formula.queue_sort()
	await get_tree().process_frame
	var speed := GameManager.game_speed
	formula.pivot_offset = formula.size * 0.5

	var windup := create_tween()
	windup.tween_property(formula, "scale", Vector2(1.1, 1.1), MERGE_ANTICIPATION / speed).set_trans(
		Tween.TRANS_SINE
	).set_ease(Tween.EASE_OUT)
	await TweenWait.finished(self, windup)

	var center_x := times_label.position.x + times_label.size.x * 0.5
	var merge := create_tween()
	merge.set_parallel(true)
	for control: Control in [flavour_label, mult_label]:
		var target_x := center_x - control.size.x * 0.5
		merge.tween_property(control, "position:x", target_x, MERGE_DURATION / speed).set_trans(
			Tween.TRANS_BACK
		).set_ease(Tween.EASE_IN)
		merge.tween_property(control, "scale", Vector2(0.3, 0.3), MERGE_DURATION / speed).set_trans(
			Tween.TRANS_QUAD
		).set_ease(Tween.EASE_IN)
		merge.tween_property(control, "modulate", Color(1.0, 1.0, 1.0, 0.0), MERGE_DURATION / speed).set_ease(
			Tween.EASE_IN
		)
	merge.tween_property(times_label, "scale", Vector2(1.6, 1.6), MERGE_DURATION * 0.5 / speed)
	merge.tween_property(times_label, "scale", Vector2.ZERO, MERGE_DURATION * 0.5 / speed).set_delay(
		MERGE_DURATION * 0.5 / speed
	)
	await TweenWait.finished(self, merge)
	formula.visible = false


## Total bursts out from where the pair met. Bigger scores print bigger, up to a cap.
func _play_total_pop(score: int) -> void:
	var speed := GameManager.game_speed
	var intensity := ScoreReadoutStyle.intensity_for_score(score)
	total_label.add_theme_font_size_override(
		"font_size",
		ScoreReadoutStyle.readout_font_size(score, TOTAL_MIN_FONT_SIZE, TOTAL_MAX_FONT_SIZE)
	)
	total_label.add_theme_color_override("font_color", ScoreReadoutStyle.color_for_score(score))
	_total_counter.snap_to(0)
	_center_total_label()
	total_label.visible = true
	total_label.scale = Vector2(0.2, 0.2)
	total_label.rotation_degrees = 0.0
	total_label.modulate = Color.WHITE

	AudioManager.play_sfx(UISounds.STATION_RESULT)
	_shake_screen(intensity)
	var count_tween := _total_counter.play(score)

	var pop_scale := lerpf(1.12, TOTAL_POP_SCALE, intensity)
	var pop := create_tween()
	pop.tween_property(total_label, "scale", Vector2(pop_scale, pop_scale), TOTAL_POP_DURATION / speed).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	pop.tween_property(total_label, "scale", Vector2.ONE, TOTAL_SETTLE_DURATION / speed).set_trans(
		Tween.TRANS_ELASTIC
	).set_ease(Tween.EASE_OUT)
	_fx_tweens[total_label] = pop

	await TweenWait.finished(self, count_tween)
	await TweenWait.finished(self, pop)


func _center_total_label() -> void:
	total_label.size = Vector2(size.x, total_label.get_combined_minimum_size().y)
	total_label.position = Vector2(0.0, (size.y - total_label.size.y) * 0.5)
	total_label.pivot_offset = total_label.size * 0.5

#endregion


#region Commit into Day Rating

func _on_round_score_commit_animation_requested(transfer_amount: int, round_score_before: int) -> void:
	if not GameManager.is_processing_turn:
		return
	_fly_into_day_rating(transfer_amount, round_score_before)


func _fly_into_day_rating(amount: int, before: int) -> void:
	var after := before + amount
	if amount <= 0 or day_rating_panel == null or not total_label.visible:
		if day_rating_panel != null:
			day_rating_panel.snap_to(after)
		if visible:
			await TweenWait.finished(self, _fade_to(false))
		EventBus.round_score_count_finished.emit()
		return

	_kill_fx()
	var speed := GameManager.game_speed
	_center_total_label()
	total_label.scale = Vector2.ONE

	var start := total_label.get_global_rect().get_center()
	var target := day_rating_panel.get_landing_point()
	var half_size := total_label.size * 0.5
	var fly := create_tween()
	fly.tween_method(
		func(t: float) -> void:
			total_label.global_position = start.lerp(target, t) - half_size
			var s := lerpf(1.0, FLY_END_SCALE, t)
			total_label.scale = Vector2(s, s),
		0.0,
		1.0,
		FLY_DURATION / speed
	).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	fly.parallel().tween_property(total_label, "modulate:a", 0.0, FLY_DURATION * 0.2 / speed).set_delay(
		FLY_DURATION * 0.8 / speed
	)
	await TweenWait.finished(self, fly)

	total_label.visible = false
	_fade_to(false)
	await day_rating_panel.play_score_gain(before, after)
	EventBus.round_score_count_finished.emit()

#endregion


#region Helpers

func _replace_fx_tween(control: Control) -> Tween:
	var existing: Variant = _fx_tweens.get(control)
	if existing is Tween and (existing as Tween).is_valid():
		(existing as Tween).kill()
	var tween := create_tween()
	_fx_tweens[control] = tween
	return tween


func _kill_fx() -> void:
	for tween: Variant in _fx_tweens.values():
		if tween is Tween and (tween as Tween).is_valid():
			(tween as Tween).kill()
	_fx_tweens.clear()


func _keep_pivot_centered(control: Control) -> void:
	control.resized.connect(func() -> void: control.pivot_offset = control.size * 0.5)


func _format_flavour(value: int) -> String:
	return "-" if value == 0 else CountingNumber.format_int(value)


func _shake_screen(intensity: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null or not camera.has_method("shake"):
		return
	camera.shake(lerpf(CAMERA_SHAKE_MIN, CAMERA_SHAKE_MAX, intensity), SHAKE_DURATION)


func _exit_tree() -> void:
	for counter: CountingNumber in [_flavour_counter, _mult_counter, _total_counter]:
		if counter != null:
			counter.kill()

#endregion
