extends PanelContainer

## Top-left event chip, docked beside the run status bar. Tooltip carries the full event copy.

@onready var event_icon: TextureRect = $EventIcon

const ACTIVE_ICON_MODULATE := Color(1.35, 1.15, 0.55)
const IDLE_ICON_MODULATE := Color.WHITE


func _ready() -> void:
	EventBus.round_changed.connect(_update_event_preview)
	EventBus.event_schedule_changed.connect(_update_event_preview)
	EventBus.event_changed.connect(_update_event_preview)

	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)

	_update_event_preview()


func _update_event_preview(_new_day: int = -1) -> void:
	if EventManager.active_event != -1:
		event_icon.modulate = ACTIVE_ICON_MODULATE
		return

	event_icon.modulate = IDLE_ICON_MODULATE


func _get_tooltip_text() -> String:
	if EventManager.active_event != -1:
		var active_name := EventManager.get_event_name(EventManager.active_event)
		var active_description := EventManager.get_event_description(EventManager.active_event)
		return "Active Event\nDay %d — %s\n%s" % [GameManager.current_round, active_name, active_description]

	var next_day: int = EventManager.get_next_event_round()
	if next_day == -1:
		return ""

	var next_event := EventManager.get_next_event_type()
	if next_event == -1:
		return ""

	var next_name := EventManager.get_event_name(next_event)
	var description := EventManager.get_event_description(next_event)
	return "Day %d — %s\n%s" % [next_day, next_name, description]


func _on_mouse_entered() -> void:
	var text := _get_tooltip_text()
	if text.is_empty():
		return
	EventBus.toggle_tooltip.emit(true, text, get_global_rect())


func _on_mouse_exited() -> void:
	EventBus.toggle_tooltip.emit(false, "")
