class_name TurnResolveSkipOverlay
extends Button

## Skip button shown while a turn resolves. Skips animations and score reveals.

const HINT_TEXT := "Skip Animation"


func _ready() -> void:
	text = HINT_TEXT
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	hide()
	pressed.connect(_on_pressed)
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_started.connect(_hide)
	EventBus.segment_turn_completed.connect(_hide)
	EventBus.game_ended.connect(_hide)


func _on_pressed() -> void:
	GameManager.request_turn_presentation_skip()


func _on_turn_ended() -> void:
	if GameManager.skip_presentation:
		return
	show()


## Shared hide handler for signals with different arity.
func _hide(_unused = null, _unused2 = null) -> void:
	hide()
