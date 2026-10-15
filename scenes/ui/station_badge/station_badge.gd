class_name StationBadge
extends PanelContainer

## Station type, level and serving progress, seated in map space left of a station row.
## Hover shows the station's meals served and its active perks.

const BADGE_WIDTH := 132.0
const PIP_SIZE := Vector2(16, 6)
const BASE_COLOR := Color(0.78, 0.72, 0.66, 1)
const PANEL_FILL := Color(0.13, 0.1, 0.12, 0.92)
const PIP_EMPTY := Color(1, 1, 1, 0.16)
const PUNCH_SCALE := 1.16
const PIP_PUNCH_SCALE := 1.8

var segment_index := -1
var _map: HexTileMap
var _icon: TextureRect
var _name_label: Label
var _level_label: Label
var _pips: Array[Panel] = []
var _progress: ProgressBar
var _progress_label: Label
var _style: StyleBoxFlat
var _progress_tween: Tween


func setup(map: HexTileMap, index: int) -> void:
	_map = map
	segment_index = index
	_build()
	mouse_entered.connect(_show_tooltip)
	mouse_exited.connect(_hide_tooltip)
	EventBus.station_state_changed.connect(_on_station_state_changed)
	EventBus.station_type_changed.connect(_on_station_type_changed)
	EventBus.station_leveled_up.connect(_on_station_leveled_up)
	refresh(false)


func _build() -> void:
	custom_minimum_size = Vector2(BADGE_WIDTH, 0)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_style = StyleBoxFlat.new()
	_style.bg_color = PANEL_FILL
	_style.set_corner_radius_all(10)
	_style.set_border_width_all(2)
	_style.content_margin_left = 8
	_style.content_margin_right = 8
	_style.content_margin_top = 6
	_style.content_margin_bottom = 6
	add_theme_stylebox_override("panel", _style)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(row)

	_icon = TextureRect.new()
	_icon.custom_minimum_size = Vector2(34, 34)
	_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(_icon)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 2)
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(column)

	var title_row := HBoxContainer.new()
	title_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(title_row)
	_name_label = _make_label(15)
	_name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title_row.add_child(_name_label)
	_level_label = _make_label(13)
	title_row.add_child(_level_label)

	var pip_row := HBoxContainer.new()
	pip_row.add_theme_constant_override("separation", 3)
	pip_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(pip_row)
	for _i in StationManager.MAX_LEVEL:
		var pip := Panel.new()
		pip.custom_minimum_size = PIP_SIZE
		pip.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var pip_style := StyleBoxFlat.new()
		pip_style.set_corner_radius_all(3)
		pip.add_theme_stylebox_override("panel", pip_style)
		pip_row.add_child(pip)
		_pips.append(pip)

	var progress_row := HBoxContainer.new()
	progress_row.add_theme_constant_override("separation", 4)
	progress_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(progress_row)
	_progress = ProgressBar.new()
	_progress.max_value = 1.0
	_progress.step = 0.0
	_progress.show_percentage = false
	_progress.custom_minimum_size = Vector2(0, 6)
	_progress.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_progress.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var track := StyleBoxFlat.new()
	track.bg_color = PIP_EMPTY
	track.set_corner_radius_all(3)
	_progress.add_theme_stylebox_override("background", track)
	var fill := StyleBoxFlat.new()
	fill.set_corner_radius_all(3)
	_progress.add_theme_stylebox_override("fill", fill)
	progress_row.add_child(_progress)
	_progress_label = _make_label(11)
	progress_row.add_child(_progress_label)


func _make_label(font_size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override("font_size", font_size)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return label


## Redraws from StationManager. animate_progress tweens the serving bar instead of snapping.
func refresh(animate_progress: bool = true) -> void:
	var station_type := StationManager.get_station_type(segment_index)
	var color := _station_color()
	var level := StationManager.get_level(segment_index)
	_icon.texture = station_type.icon if station_type != null else null
	_icon.visible = station_type != null
	_name_label.text = StationManager.get_station_name(segment_index)
	_name_label.add_theme_color_override("font_color", color)
	_level_label.text = "Lv %d" % level
	_style.border_color = color.darkened(0.15)
	for i in _pips.size():
		var pip_style := _pips[i].get_theme_stylebox("panel") as StyleBoxFlat
		pip_style.bg_color = color if i < level else PIP_EMPTY

	# Base stations do not progress, so they show no serving bar.
	_progress.get_parent().visible = station_type != null
	var served := StationManager.get_served(segment_index)
	var next := StationManager.get_next_threshold(segment_index)
	var floor_count := StationManager.get_current_threshold(segment_index)
	var fill := _progress.get_theme_stylebox("fill") as StyleBoxFlat
	fill.bg_color = color
	if next < 0:
		_progress_label.text = "MAX"
		_set_progress(1.0, animate_progress)
	else:
		_progress_label.text = "%d/%d" % [served, next]
		var span := maxi(next - floor_count, 1)
		_set_progress(float(served - floor_count) / float(span), animate_progress)


func _set_progress(ratio: float, animate: bool) -> void:
	if _progress_tween != null and _progress_tween.is_valid():
		_progress_tween.kill()
	if not animate or GameManager.skip_presentation or not is_inside_tree():
		_progress.value = ratio
		return
	_progress_tween = create_tween()
	_progress_tween.tween_property(_progress, "value", ratio, 0.35 / _speed()).set_trans(
		Tween.TRANS_CUBIC
	).set_ease(Tween.EASE_OUT)


func _on_station_state_changed(index: int) -> void:
	if index == segment_index:
		refresh()


func _on_station_type_changed(index: int, _type_id: String) -> void:
	if index != segment_index or GameManager.skip_presentation:
		return
	AudioManager.play_sfx(UISounds.STATION_TYPE_GAINED)
	# Flip on the X axis, swapping to the new type at the edge, then punch.
	pivot_offset = size * 0.5
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2(0.0, 1.0), 0.14 / _speed()).set_trans(Tween.TRANS_SINE)
	tween.tween_callback(refresh.bind(false))
	_append_punch(tween, self, PUNCH_SCALE)
	_float_text("%s!" % StationManager.get_station_name(segment_index), _station_color())
	_map.flash_segment_highlight(segment_index)


func _on_station_leveled_up(index: int, level: int) -> void:
	if index != segment_index or GameManager.skip_presentation:
		return
	AudioManager.play_sfx(UISounds.STATION_LEVEL_UP)
	_append_punch(create_tween(), self, PUNCH_SCALE)
	if level >= 1 and level <= _pips.size():
		_append_punch(create_tween(), _pips[level - 1], PIP_PUNCH_SCALE)
	_float_text("Level %d" % level, _station_color())
	if level == StationManager.MEAL_SLOT_UNLOCK_LEVEL:
		AudioManager.play_sfx(UISounds.MEAL_SLOT_UNLOCKED)


## Pop target up to peak scale and settle back, after whatever tween already holds.
func _append_punch(tween: Tween, target: Control, peak: float) -> void:
	target.pivot_offset = target.size * 0.5
	tween.tween_property(target, "scale", Vector2.ONE * peak, 0.14 / _speed()).set_trans(
		Tween.TRANS_BACK
	).set_ease(Tween.EASE_OUT)
	tween.tween_property(target, "scale", Vector2.ONE, 0.2 / _speed()).set_trans(Tween.TRANS_SINE)


func _station_color() -> Color:
	var station_type := StationManager.get_station_type(segment_index)
	return station_type.color if station_type != null else BASE_COLOR


func _speed() -> float:
	return maxf(GameManager.game_speed, 0.01)


func _float_text(text: String, color: Color) -> void:
	if _map == null:
		return
	var center := get_global_transform() * (size * 0.5)
	_map.create_floating_text(center + Vector2(0, -size.y), text, color)


#region --- Tooltip ---

func _show_tooltip() -> void:
	var screen_rect := get_global_transform_with_canvas() * Rect2(Vector2.ZERO, size)
	EventBus.toggle_tooltip.emit(true, get_tooltip_body(), screen_rect)


func _hide_tooltip() -> void:
	EventBus.toggle_tooltip.emit(false, "", Rect2())


## First line is the tooltip header, the rest is body copy.
func get_tooltip_body() -> String:
	var lines: PackedStringArray = [StationManager.get_station_name(segment_index)]
	var station_type := StationManager.get_station_type(segment_index)
	if station_type == null:
		lines.append("No specialty yet.")
		return "\n".join(lines)
	var next := StationManager.get_next_threshold(segment_index)
	if next >= 0:
		lines.append("Meals served: %d/%d" % [StationManager.get_served(segment_index), next])
	var current := station_type.perk_for_level(StationManager.get_level(segment_index))
	if current != null:
		lines.append(current.description)
	var chosen := StationManager.get_chosen_perk(segment_index)
	if chosen != null:
		lines.append(chosen.description)
	return CardKeywordGlossary.to_plain("\n".join(lines))

#endregion --- Tooltip ---
