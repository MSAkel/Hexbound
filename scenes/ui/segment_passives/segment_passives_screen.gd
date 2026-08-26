extends Control

## Pre-run screen for arranging segment passives into the A/B/C sets of one character.

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")
const MAP_VIEW_SCRIPT := preload("res://scenes/ui/segment_passives/segment_passives_map_view.gd")
const CHARACTER_SELECTION_SCENE := preload(
	"res://scenes/ui/character_selection_screen/character_selection_screen.tscn"
)

const COLOR_TITLE := Color(0.18, 0.24, 0.17, 1.0)
const COLOR_BODY := Color(0.39, 0.31, 0.2, 1.0)
const COLOR_MUTED := Color(0.45, 0.4, 0.32, 1.0)

@onready var subtitle_label: Label = %SubtitleLabel
@onready var passive_list: VBoxContainer = %PassiveList
@onready var map_host: Control = %MapHost
@onready var segment_title: Label = %SegmentTitle
@onready var slots_label: Label = %SlotsLabel
@onready var placed_list: VBoxContainer = %PlacedList
@onready var effects_list: VBoxContainer = %EffectsList
@onready var set_tabs: HBoxContainer = %SetTabs
@onready var reset_segment_button: Button = %ResetSegmentButton

var _character: CharacterDefinition = null
var _active_set_id: String = "A"
var _map_view: SegmentPassivesMapView = null
var _selected_segment_index: int = -1


func _ready() -> void:
	_build_set_tabs()
	var character := GameManager.segment_passives_editor_character
	if character == null:
		character = GameManager.selected_character
	if character != null:
		open_for_character(character)


func _exit_tree() -> void:
	if _map_view != null:
		_map_view.cleanup()


func open_for_character(character: CharacterDefinition) -> void:
	_character = character
	_active_set_id = MetaProgressionManager.get_selected_set_id(character.id)
	subtitle_label.text = character.display_name.to_upper()
	if MetaProgressionManager.is_ui_sandbox():
		subtitle_label.text = "SANDBOX  ·  %s" % character.display_name.to_upper()
	_selected_segment_index = -1
	_refresh_set_tab_states()
	_rebuild_map_view()
	_refresh_passive_list()
	_refresh_segment_panel()


#region Loadout set tabs

func _build_set_tabs() -> void:
	for set_id: String in MetaProgressionManager.LOADOUT_SET_IDS:
		var button := Button.new()
		button.text = set_id
		button.toggle_mode = true
		button.focus_mode = Control.FOCUS_NONE
		button.custom_minimum_size = Vector2(64.0, 48.0)
		button.add_theme_font_size_override("font_size", 22)
		button.add_theme_color_override("font_color", Color(0.18, 0.24, 0.17, 1.0))
		button.add_theme_color_override("font_pressed_color", Color(0.96, 0.84, 0.62, 1.0))
		button.add_theme_color_override("font_hover_color", Color(0.12, 0.18, 0.12, 1.0))
		# button_pressed drives the active look, so the toggled-on styles double as "selected".
		button.add_theme_stylebox_override("normal", _make_tab_style(false))
		button.add_theme_stylebox_override("hover", _make_tab_style(false, true))
		button.add_theme_stylebox_override("pressed", _make_tab_style(true))
		button.add_theme_stylebox_override("hover_pressed", _make_tab_style(true))
		button.pressed.connect(_on_set_tab_pressed.bind(set_id))
		set_tabs.add_child(button)


func _make_tab_style(active: bool, hovered: bool = false) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	if active:
		style.bg_color = Color(0.055, 0.22, 0.25, 0.96)
		style.border_color = Color(0.78, 0.61, 0.31, 1.0)
	else:
		style.bg_color = Color(0.9, 0.86, 0.72, 0.92) if not hovered else Color(0.96, 0.92, 0.8, 0.96)
		style.border_color = Color(0.55, 0.42, 0.22, 0.75)
	style.set_border_width_all(2)
	style.set_corner_radius_all(8)
	return style


func _refresh_set_tab_states() -> void:
	for index in set_tabs.get_child_count():
		var button := set_tabs.get_child(index) as Button
		if button == null:
			continue
		button.button_pressed = MetaProgressionManager.LOADOUT_SET_IDS[index] == _active_set_id


func _on_set_tab_pressed(set_id: String) -> void:
	if _character == null:
		return
	_active_set_id = set_id
	MetaProgressionManager.set_selected_set_id(_character.id, set_id)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_refresh_set_tab_states()
	_selected_segment_index = -1
	if _map_view != null:
		_map_view.setup(_character, _active_set_id)
	_refresh_passive_list()
	_refresh_segment_panel()

#endregion

#region Map

func _rebuild_map_view() -> void:
	for child in map_host.get_children():
		child.queue_free()
	if _character == null:
		return

	_map_view = MAP_VIEW_SCRIPT.new()
	_map_view.set_anchors_preset(Control.PRESET_FULL_RECT)
	_map_view.segment_selected.connect(_on_segment_selected)
	_map_view.passive_remove_requested.connect(_on_map_passive_remove_requested)
	_map_view.passive_drop_requested.connect(_on_passive_dropped)
	_map_view.passive_move_requested.connect(_on_passive_moved)
	map_host.add_child(_map_view)
	_map_view.setup(_character, _active_set_id)


func _on_segment_selected(segment_index: int) -> void:
	_selected_segment_index = segment_index
	AudioManager.play_sfx(UI_SOUNDS.SELECT)
	_refresh_passive_list()
	_refresh_segment_panel()


func _on_map_passive_remove_requested(segment_index: int, list_index: int) -> void:
	_selected_segment_index = segment_index
	_on_remove_passive_pressed(list_index)


func _get_segment_capacity(segment_index: int) -> int:
	if _map_view == null:
		return 0
	return _map_view.get_segment_capacity(segment_index)

#endregion

#region Passive list

func _refresh_passive_list() -> void:
	for child in passive_list.get_children():
		child.queue_free()
	if _character == null:
		return

	var capacity := _get_segment_capacity(_selected_segment_index)
	for passive in MetaProgressionManager.get_all_passives_for_character(_character.id):
		var unlocked := MetaProgressionManager.is_unlocked(passive.id)
		var remaining := MetaProgressionManager.get_remaining_copies(
			_character.id,
			_active_set_id,
			passive.id
		)
		var selectable := _selected_segment_index >= 0 and MetaProgressionManager.can_place_passive(
			_character.id,
			_active_set_id,
			_selected_segment_index,
			passive.id,
			capacity
		)
		var item := SegmentPassiveListItem.new()
		passive_list.add_child(item)
		item.setup(
			passive,
			unlocked,
			MetaProgressionManager.get_unlock_progress_value(passive),
			selectable,
			remaining
		)
		item.passive_pressed.connect(_on_passive_pressed)


func _on_passive_pressed(passive_id: String) -> void:
	_try_place_passive(_selected_segment_index, passive_id)


func _on_passive_dropped(segment_index: int, passive_id: String) -> void:
	_try_place_passive(segment_index, passive_id)


## Board drag drop. Moves onto empty dest tiles, swaps when both sides fit,
## and deletes the dest passive when origin cannot take the swap.
func _on_passive_moved(
	from_segment: int,
	from_list_index: int,
	to_segment: int,
	to_coords: Vector2i
) -> void:
	if _character == null or _map_view == null:
		return
	var dest_list_index: int = _map_view.get_tile_placement_index(to_coords)
	var result := MetaProgressionManager.try_relocate_passive(
		_character.id,
		_active_set_id,
		from_segment,
		from_list_index,
		to_segment,
		dest_list_index,
		_get_segment_capacity(from_segment),
		_get_segment_capacity(to_segment)
	)
	if not bool(result.get("success", false)):
		AudioManager.play_sfx(UI_SOUNDS.SELECT)
		return
	_selected_segment_index = to_segment
	_refresh_passive_list()
	_refresh_segment_panel()
	_map_view.play_placement_animation(to_segment, int(result.get("dest_list_index", -1)))


func _try_place_passive(segment_index: int, passive_id: String) -> void:
	if _character == null or segment_index < 0:
		AudioManager.play_sfx(UI_SOUNDS.SELECT)
		return

	_selected_segment_index = segment_index
	var placed := MetaProgressionManager.place_passive(
		_character.id,
		_active_set_id,
		segment_index,
		passive_id,
		_get_segment_capacity(segment_index)
	)
	if not placed:
		AudioManager.play_sfx(UI_SOUNDS.SELECT)
		return
	_refresh_passive_list()
	_refresh_segment_panel()
	var placed_ids := MetaProgressionManager.get_placed_passive_ids(
		_character.id,
		_active_set_id,
		segment_index
	)
	if _map_view != null and not placed_ids.is_empty():
		_map_view.play_placement_animation(segment_index, placed_ids.size() - 1)

#endregion

#region Segment detail panel

func _refresh_segment_panel() -> void:
	for child in placed_list.get_children():
		child.queue_free()
	for child in effects_list.get_children():
		child.queue_free()

	if _character == null or _selected_segment_index < 0:
		segment_title.text = "SELECT A SEGMENT"
		slots_label.text = "Click a tile on the map"
		reset_segment_button.disabled = true
		placed_list.add_child(_make_label("No segment selected.", 15, COLOR_MUTED, true))
		if _map_view != null:
			_map_view.refresh_placements()
		return

	var passive_ids := MetaProgressionManager.get_placed_passive_ids(
		_character.id,
		_active_set_id,
		_selected_segment_index
	)
	var placed_passives: Array[SegmentPassive] = []
	for passive_id: String in passive_ids:
		var passive := MetaProgressionManager.get_passive_by_id(passive_id)
		if passive != null:
			placed_passives.append(passive)

	var capacity := _get_segment_capacity(_selected_segment_index)
	segment_title.text = "SEGMENT %d" % (_selected_segment_index + 1)
	slots_label.text = "%d tiles" % capacity
	reset_segment_button.disabled = placed_passives.is_empty()

	if placed_passives.is_empty():
		placed_list.add_child(_make_label("Nothing placed yet.", 15, COLOR_MUTED, true))
	else:
		for index in placed_passives.size():
			placed_list.add_child(_build_placed_row(placed_passives[index], index))

	var effect_lines := _build_effect_lines(placed_passives)
	if effect_lines.is_empty():
		effects_list.add_child(_make_label("No effects on this segment.", 15, COLOR_MUTED, true))
	else:
		for line: String in effect_lines:
			effects_list.add_child(_make_label(line, 15, COLOR_BODY, true))

	if _map_view != null:
		_map_view.refresh_placements()


func _build_placed_row(passive: SegmentPassive, list_index: int) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var icon := TextureRect.new()
	icon.custom_minimum_size = Vector2(36.0, 36.0)
	icon.texture = passive.icon
	icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(icon)

	var name_label := _make_label(passive.display_name, 16, COLOR_TITLE)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(name_label)

	var tile_count := maxi(1, passive.tile_cost)
	var cost_label := _make_label("%d tile%s" % [tile_count, "" if tile_count == 1 else "s"], 13, COLOR_MUTED)
	cost_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(cost_label)

	var remove_button := Button.new()
	remove_button.text = "X"
	remove_button.custom_minimum_size = Vector2(32.0, 32.0)
	remove_button.focus_mode = Control.FOCUS_NONE
	remove_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	remove_button.add_theme_font_size_override("font_size", 15)
	remove_button.pressed.connect(_on_remove_passive_pressed.bind(list_index))
	row.add_child(remove_button)
	return row


## Collapses placed passives into one readable line per effect type.
func _build_effect_lines(passives: Array[SegmentPassive]) -> Array[String]:
	var score_mult := 0.0
	var score_flat := 0.0
	var support_retrigger := 0.0
	var power_output := 0.0
	var production_retrigger := 0.0
	for passive in passives:
		match passive.effect_type:
			SegmentPassive.EffectType.SEGMENT_SCORE_MULT:
				score_mult += passive.effect_value
			SegmentPassive.EffectType.SEGMENT_SCORE_FLAT:
				score_flat += passive.effect_value
			SegmentPassive.EffectType.SUPPORT_RETRIGGER:
				support_retrigger += passive.effect_value
			SegmentPassive.EffectType.CARD_OUTPUT_MULT:
				power_output += passive.effect_value
			SegmentPassive.EffectType.PRODUCTION_RETRIGGER:
				production_retrigger += passive.effect_value

	var lines: Array[String] = []
	if score_mult > 0.0:
		lines.append("+%d%% Score" % int(round(score_mult * 100.0)))
	if score_flat > 0.0:
		lines.append("+%d Score each turn" % int(score_flat))
	if power_output > 0.0:
		lines.append("+%d%% Power output" % int(round(power_output * 100.0)))
	if support_retrigger > 0.0:
		lines.append("Support cards: %d%% retrigger" % int(round(support_retrigger * 100.0)))
	if production_retrigger > 0.0:
		lines.append("Production cards: %d%% retrigger" % int(round(production_retrigger * 100.0)))
	return lines


func _on_remove_passive_pressed(list_index: int) -> void:
	if _character == null or _selected_segment_index < 0:
		return
	MetaProgressionManager.remove_passive_at(
		_character.id,
		_active_set_id,
		_selected_segment_index,
		list_index
	)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_refresh_passive_list()
	_refresh_segment_panel()


func _on_reset_segment_pressed() -> void:
	if _character == null or _selected_segment_index < 0:
		return
	MetaProgressionManager.reset_segment(_character.id, _active_set_id, _selected_segment_index)
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	_refresh_passive_list()
	_refresh_segment_panel()

#endregion

func _on_back_pressed() -> void:
	AudioManager.play_sfx(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_packed(CHARACTER_SELECTION_SCENE)


func _make_label(text: String, font_size: int, color: Color, wrap: bool = false) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	if wrap:
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	return label
