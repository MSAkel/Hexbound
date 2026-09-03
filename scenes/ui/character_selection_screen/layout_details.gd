class_name LayoutDetails
extends HBoxContainer

const DEFAULT_SEGMENT_COUNT := 7
const LEGEND_HOVER_MODULATE := Color(1.08, 1.05, 0.92, 1.0)

# Kept in sync by display_selection so Play can lock in the visible layout.
var _selected_character: CharacterDefinition = null

@onready var character_name_label: Label = %CharacterNameLabel
@onready var layout_level_label: Label = %LayoutLevelLabel
@onready var layout_xp_label: Label = %LayoutXpLabel
@onready var passive_set_label: Label = %PassiveSetLabel
@onready var character_icon: TextureRect = %CharacterIcon
@onready var trigger_order_label: Label = %TriggerOrderLabel
@onready var trigger_order_description: Label = %TriggerOrderDescription
@onready var layout_preview_map: LayoutPreviewMap = %LayoutPreviewMap
@onready var segment_count_label: Label = %SegmentCountTitle
@onready var legend_trigger_order: PanelContainer = %LegendTriggerOrder
@onready var legend_segments: PanelContainer = %LegendSegments
@onready var legend_segment_start: PanelContainer = %LegendSegmentStart
@onready var legend_segment_end: PanelContainer = %LegendSegmentEnd


func _ready() -> void:
	_bind_legend_item(legend_trigger_order, LayoutPreviewMap.LegendFilter.TRIGGER_ORDER)
	_bind_legend_item(legend_segments, LayoutPreviewMap.LegendFilter.SEGMENTS)
	_bind_legend_item(legend_segment_start, LayoutPreviewMap.LegendFilter.STARTS)
	_bind_legend_item(legend_segment_end, LayoutPreviewMap.LegendFilter.ENDS)


func display_selection(character: CharacterDefinition) -> void:
	_selected_character = character
	character_name_label.text = character.display_name.to_upper()
	character_icon.texture = character.icon
	trigger_order_label.text = character.trigger_order_display_name.to_upper()
	trigger_order_description.text = character.trigger_order_description
	layout_preview_map.setup(character)

	var segment_count := DEFAULT_SEGMENT_COUNT
	if not character.segment_starts.is_empty():
		segment_count = character.segment_starts.size()
	elif character.segments_count > 0:
		segment_count = character.segments_count
	segment_count_label.text = FeastDisplay.courses_count_label(segment_count)
	_refresh_layout_progress(character)
	_refresh_passive_set_label(character)


func get_selected_character() -> CharacterDefinition:
	return _selected_character


func _refresh_layout_progress(character: CharacterDefinition) -> void:
	var level := MetaProgressionManager.get_layout_level(character.id)
	layout_level_label.text = "Level %d" % level
	if level >= MetaProgressionManager.LAYOUT_LEVEL_XP.size():
		layout_xp_label.hide()
		return
	var xp := MetaProgressionManager.get_layout_xp(character.id)
	var next_xp := MetaProgressionManager.get_layout_xp_for_next_level(character.id)
	layout_xp_label.text = "%d/%d EXP" % [xp, next_xp]
	layout_xp_label.show()


func _refresh_passive_set_label(character: CharacterDefinition) -> void:
	var set_id := MetaProgressionManager.get_selected_set_id(character.id)
	passive_set_label.text = "Set %s" % set_id


func _bind_legend_item(item: PanelContainer, filter: LayoutPreviewMap.LegendFilter) -> void:
	item.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	item.mouse_entered.connect(_on_legend_item_mouse_entered.bind(item, filter))
	item.mouse_exited.connect(_on_legend_item_mouse_exited.bind(item))


func _on_legend_item_mouse_entered(item: PanelContainer, filter: LayoutPreviewMap.LegendFilter) -> void:
	item.modulate = LEGEND_HOVER_MODULATE
	layout_preview_map.set_legend_filter(filter)


func _on_legend_item_mouse_exited(item: PanelContainer) -> void:
	item.modulate = Color.WHITE
	layout_preview_map.set_legend_filter(LayoutPreviewMap.LegendFilter.NONE)


func _on_segment_passives_button_pressed() -> void:
	if _selected_character == null:
		return
	AudioManager.play_sfx(UISounds.CLICK)
	GameManager.segment_passives_editor_character = _selected_character
	get_tree().change_scene_to_file(ScenePaths.SEGMENT_PASSIVES)
