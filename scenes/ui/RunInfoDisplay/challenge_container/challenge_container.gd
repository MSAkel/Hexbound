extends Control

@onready var event_panel: PanelContainer = $"."
@onready var next_event_round: Label = $VBoxContainer/NextEventRound
@onready var event_name: Label = $VBoxContainer/EventName
@onready var event_description: Label = $VBoxContainer/EventDescription
@onready var event_icon: TextureRect = $TextureRect

const ACTIVE_ICON_MODULATE := Color(1.35, 1.15, 0.55)
const IDLE_ICON_MODULATE := Color.WHITE


func _ready() -> void:
	EventBus.round_changed.connect(_update_event_preview)
	EventBus.event_schedule_changed.connect(_update_event_preview)
	EventBus.event_changed.connect(_update_event_preview)

	event_panel.mouse_entered.connect(_on_mouse_entered)
	event_panel.mouse_exited.connect(_on_mouse_exited)

	_update_event_preview()


func _update_event_preview(_new_round: int = -1) -> void:
	# Keep showing the active event name until its round completes.
	if EventManager.active_event != -1:
		event_name.text = EventManager.get_event_name(EventManager.active_event)
		event_icon.modulate = ACTIVE_ICON_MODULATE
		return

	event_icon.modulate = IDLE_ICON_MODULATE

	var next_round: int = EventManager.get_next_event_round()
	if next_round == -1:
		next_event_round.text = "None"
		event_name.text = ""
		event_description.text = ""
		return

	var next_event := EventManager.get_next_event_type()
	next_event_round.text = "Round %s" % next_round
	if next_event == -1:
		event_name.text = ""
		event_description.text = ""
	else:
		event_name.text = EventManager.get_event_name(next_event)
		event_description.text = EventManager.get_event_description(next_event)


func _get_tooltip_text() -> String:
	if EventManager.active_event != -1:
		var active_name := EventManager.get_event_name(EventManager.active_event)
		var description := EventManager.get_event_description(EventManager.active_event)
		return "Active Event\nRound %d — %s\n%s" % [GameManager.current_round, active_name, description]

	var next_round: int = EventManager.get_next_event_round()
	if next_round == -1:
		return ""

	var next_event := EventManager.get_next_event_type()
	if next_event == -1:
		return ""

	return "Round %d\n%s" % [next_round, EventManager.get_event_description(next_event)]


func _get_tooltip_rect() -> Rect2:
	return event_panel.get_global_rect()


func _on_mouse_entered() -> void:
	var text := _get_tooltip_text()
	if text.is_empty():
		return
	EventBus.toggle_tooltip.emit(true, text, _get_tooltip_rect())


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
