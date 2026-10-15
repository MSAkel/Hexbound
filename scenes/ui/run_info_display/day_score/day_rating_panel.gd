class_name DayRatingPanel
extends PanelContainer

## Day Rating so far. The Hour score flies in and counts this up each turn.

const MIN_FONT_SIZE := 34
const MAX_FONT_SIZE := 46
const GOAL_MET_BORDER := Color(0.85, 0.62, 0.12, 1.0)

@onready var caption_label: Label = $Row/CaptionLabel
@onready var score_label: Label = $Row/ScoreLabel

var _counter: CountingNumber
var _panel_style: StyleBoxFlat
var _land_tweens: Array[Tween] = []
var _value := 0


func _ready() -> void:
	_panel_style = get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	add_theme_stylebox_override("panel", _panel_style)
	caption_label.text = "%s %s" % [GameTerms.DAY.to_upper(), GameTerms.RATING.to_upper()]
	_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		_on_counted
	)
	snap_to(GameManager.total_round_score)

	EventBus.total_round_score_changed.connect(_on_total_round_score_changed)
	EventBus.required_score_changed.connect(_refresh_style)
	clip_contents = false


func snap_to(value: int) -> void:
	_counter.snap_to(value)


## Screen-space point the Hour score flies into.
func get_landing_point() -> Vector2:
	return score_label.get_global_rect().get_center()


## Counts from from_score to to_score with a land punch. Await to wait for the whole beat.
func play_score_gain(from_score: int, to_score: int) -> void:
	_counter.snap_to(from_score)
	var intensity := ScoreReadoutStyle.intensity_for_score(to_score - from_score)
	_land_tweens = [
		ScoreLandFx.play_number_land(self, score_label, intensity),
		ScoreLandFx.play_panel_pulse(self, self),
	]
	ScoreBurstFx.play_background_wash(self, intensity, true)
	var count_tween := _counter.play(to_score)
	await TweenWait.finished(self, count_tween)
	for tween in _land_tweens:
		await TweenWait.finished(self, tween)
	_land_tweens.clear()


func _on_total_round_score_changed() -> void:
	# Turn resolve counts this up when the Hour score lands.
	if GameManager.is_processing_turn:
		return
	snap_to(GameManager.total_round_score)


func _on_counted(value: int) -> void:
	_value = value
	score_label.text = CountingNumber.format_int(value)
	_refresh_style()


func _refresh_style() -> void:
	var value := _value
	var intensity := ScoreReadoutStyle.intensity_for_score(value)
	var ink := ScoreReadoutStyle.ink_color_for_intensity(intensity)
	score_label.add_theme_color_override("font_color", ink)
	score_label.add_theme_color_override("font_shadow_color", Color(0.24, 0.16, 0.06, 0.16 + intensity * 0.16))
	var digit_penalty := maxi(score_label.text.length() - 8, 0)
	score_label.add_theme_font_size_override(
		"font_size",
		maxi(28, ScoreReadoutStyle.readout_font_size(value, MIN_FONT_SIZE, MAX_FONT_SIZE) - digit_penalty * 2)
	)
	ScoreLandFx.refresh_text_pivot(score_label)
	if _panel_style == null:
		return
	var goal_met := GameManager.required_score > 0 and value >= GameManager.required_score
	_panel_style.border_color = (
		GOAL_MET_BORDER if goal_met else Color(ink.r, ink.g, ink.b, 0.62 + intensity * 0.28)
	)
	_panel_style.border_width_bottom = 3 if goal_met else 1
	_panel_style.shadow_color = Color(0.24, 0.16, 0.06, 0.14 + intensity * 0.12)


func _exit_tree() -> void:
	if _counter != null:
		_counter.kill()
