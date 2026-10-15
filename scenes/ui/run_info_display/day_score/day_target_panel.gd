class_name DayTargetPanel
extends PanelContainer

## Day Rating needed to clear the current day.

@onready var caption_label: Label = $Row/CaptionLabel
@onready var target_label: Label = $Row/TargetLabel

var _counter: CountingNumber


func _ready() -> void:
	caption_label.text = "%s TARGET" % GameTerms.DAY.to_upper()
	_counter = CountingNumber.for_label(self, target_label, true)
	_counter.snap_to(GameManager.required_score)
	EventBus.required_score_changed.connect(_on_required_score_changed)


func _on_required_score_changed() -> void:
	if _counter.play(GameManager.required_score) != null:
		ScoreLandFx.play_number_land(self, target_label, 0.4)


func _exit_tree() -> void:
	if _counter != null:
		_counter.kill()
