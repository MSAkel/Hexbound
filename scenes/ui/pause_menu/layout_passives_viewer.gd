class_name LayoutPassivesViewer
extends Control

## Read-only pause overlay for the run's current layout passives.

signal closed

const MAP_VIEW_SCRIPT := preload("res://scenes/ui/segment_passives/segment_passives_map_view.gd")

@onready var subtitle_label: Label = %SubtitleLabel
@onready var map_host: Control = %MapHost

var _map_view: SegmentPassivesMapView = null


func _ready() -> void:
	if not %BackButton.pressed.is_connected(_on_back_pressed):
		%BackButton.pressed.connect(_on_back_pressed)
	visibility_changed.connect(_on_visibility_changed)


func _exit_tree() -> void:
	_teardown_map()


func _on_visibility_changed() -> void:
	if not visible:
		_teardown_map()
		return
	# Hidden overlays often have a zero size until the current frame lays out.
	await get_tree().process_frame
	if not visible:
		return
	_rebuild_map_view()


func _rebuild_map_view() -> void:
	_teardown_map()
	var character := GameManager.selected_character
	if character == null:
		subtitle_label.text = "No Layout Selected"
		return

	var set_id := MetaProgressionManager.get_selected_set_id(character.id)
	subtitle_label.text = "%s  ·  SET %s" % [character.display_name.to_upper(), set_id]

	_map_view = MAP_VIEW_SCRIPT.new()
	# Inspection only. The map view still draws hover tooltips.
	_map_view.read_only = true
	# Ignore on the root so an oversized map rect cannot steal header clicks.
	# Hex tiles still use STOP and receive their own events.
	_map_view.mouse_filter = Control.MOUSE_FILTER_IGNORE
	map_host.clip_contents = true
	map_host.add_child(_map_view)
	_map_view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_map_view.setup(character, set_id)


func _teardown_map() -> void:
	if _map_view != null:
		_map_view.cleanup()
		_map_view.queue_free()
		_map_view = null
	if map_host == null:
		return
	for child in map_host.get_children():
		child.queue_free()


func _on_back_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()
