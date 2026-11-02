class_name DayRatingPanel
extends PanelContainer

## Day Rating so far. The Hour score flies in and counts this up each turn.

@onready var caption_label: Label = $Row/CaptionLabel
@onready var score_label: Label = $Row/ScoreLabel

var _counter: CountingNumber
var _land_tweens: Array[Tween] = []


func _ready() -> void:
	caption_label.text = "%s %s" % [GameTerms.DAY.to_upper(), GameTerms.RATING.to_upper()]
	_counter = CountingNumber.new(
		self,
		func(_text: String) -> void: pass,
		false,
		_on_counted
	)
	snap_to(GameManager.total_round_score)

	EventBus.total_round_score_changed.connect(_on_total_round_score_changed)
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
	score_label.text = CountingNumber.format_int(value)
	ScoreLandFx.refresh_text_pivot(score_label)


func _exit_tree() -> void:
	if _counter != null:
		_counter.kill()
