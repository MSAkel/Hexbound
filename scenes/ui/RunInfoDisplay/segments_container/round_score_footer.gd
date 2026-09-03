extends PanelContainer

## Round score footer. Hero number on the right, target shown as a quiet subtitle on the left.

@onready var target_label: Label = $TotalRow/TotalCopy/TargetLabel
@onready var score_this_round: Label = $TotalRow/ScoreThisRound

var _round_score_counter: CountingNumber
var _target_counter: CountingNumber
var _panel_style: StyleBoxFlat


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
		func(text: String) -> void: target_label.text = "%s TARGET %s" % [FeastDisplay.DAY.to_upper(), text],
		true
	)

	_round_score_counter.snap_to(GameManager.total_round_score)
	_target_counter.snap_to(GameManager.required_score)

	EventBus.total_round_score_changed.connect(_on_total_round_score_changed)
	EventBus.required_score_changed.connect(_on_required_score_changed)

	clip_contents = false


func _on_total_round_score_changed() -> void:
	# Turn resolve plays the transfer after the turn-total punch lands.
	if GameManager.is_processing_turn:
		return
	_round_score_counter.snap_to(GameManager.total_round_score)
	_style_round_score(GameManager.total_round_score)


## Counts the round score up during the post-turn transfer from the turn total.
func play_transfer_fill(from_score: int, to_score: int) -> Tween:
	_round_score_counter.snap_to(from_score)
	_style_round_score(from_score)
	score_this_round.text = CountingNumber.format_int(from_score)
	return _round_score_counter.play(to_score)


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


func _exit_tree() -> void:
	if _round_score_counter != null:
		_round_score_counter.kill()
	if _target_counter != null:
		_target_counter.kill()
