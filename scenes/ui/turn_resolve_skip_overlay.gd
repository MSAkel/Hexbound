class_name TurnResolveSkipOverlay
extends Control

## Full-screen click catcher while a turn resolves. Skips animations and score reveals.

@onready var _hint: Label = $Hint

const HINT_TEXT := "Click to skip"


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	z_index = 45
	hide()
	EventBus.turn_ended.connect(_on_turn_ended)
	EventBus.turn_started.connect(_hide)
	EventBus.segment_turn_completed.connect(_hide)
	EventBus.game_ended.connect(_hide)


func _gui_input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		GameManager.request_turn_presentation_skip()
		accept_event()


func _on_turn_ended() -> void:
	if GameManager.skip_presentation:
		return
	_hint.text = HINT_TEXT
	show()


## Shared hide handler for signals with different arity.
func _hide(_unused = null, _unused2 = null) -> void:
	hide()
