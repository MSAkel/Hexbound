class_name StationUpgradeChoice
extends Control

## Level 3 perk pick for a typed station. Opens over the board when StationManager asks for it,
## blocks play until the player picks, and keeps any Hour in progress waiting meanwhile.

const DIM_COLOR := Color(0.098, 0.096, 0.092, 0.72)
const OPTION_FILL := Color(0.13, 0.1, 0.12, 0.96)
const OPTION_SIZE := Vector2(300, 190)
const HOVER_SCALE := 1.05
const PICK_SCALE := 1.12

var _segment_index := -1
var _dim: ColorRect
var _title: Label
var _subtitle: Label
var _options_row: HBoxContainer
var _board_view_button: Button
## True while the options are hidden so the player can inspect the board.
var _board_view := false
var _option_panels: Array[PanelContainer] = []
## Option lifted by mouse hover or keyboard focus, -1 for none.
var _focus_index := -1
var _picking := false


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build()
	hide()
	EventBus.station_choice_requested.connect(_on_station_choice_requested)
	StationManager.choice_resolved.connect(_on_choice_resolved)


func _build() -> void:
	_dim = ColorRect.new()
	_dim.color = DIM_COLOR
	_dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 18)
	content.alignment = BoxContainer.ALIGNMENT_CENTER
	content.mouse_filter = Control.MOUSE_FILTER_IGNORE
	center.add_child(content)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 40)
	content.add_child(_title)

	_subtitle = Label.new()
	_subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_subtitle.add_theme_font_size_override("font_size", 20)
	_subtitle.text = "Level %d reached. Choose one perk for this station." % StationManager.CHOICE_LEVEL
	content.add_child(_subtitle)

	_options_row = HBoxContainer.new()
	_options_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_options_row.add_theme_constant_override("separation", 36)
	_options_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	content.add_child(_options_row)

	# Pinned top center, like the card pick, so it stays put and off the board when the options hide.
	_board_view_button = Button.new()
	_board_view_button.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_board_view_button.offset_left = -90.0
	_board_view_button.offset_right = 90.0
	_board_view_button.offset_top = 32.0
	_board_view_button.offset_bottom = 72.0
	_board_view_button.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_board_view_button.pressed.connect(func() -> void: _set_board_view(not _board_view))
	add_child(_board_view_button)


func _on_station_choice_requested(segment_index: int) -> void:
	var station_type := StationManager.get_station_type(segment_index)
	if station_type == null or station_type.choice_options.is_empty():
		return
	_segment_index = segment_index
	_picking = false
	_populate(station_type)
	# Never steal the card pick or merchant. Sit on top of them instead.
	if UiManager.active_panel == null or not UiManager.active_panel.visible:
		UiManager.show_panel(self)
	else:
		show()
	move_to_front()
	_set_board_view(false)
	EventBus.toggle_tooltip.emit(false, "", Rect2())
	if not GameManager.skip_presentation:
		AudioManager.play_sfx(UISounds.CARD_REVEAL)
	_play_intro()


## The station lost its type while its pick was open. Close without picking.
func _on_choice_resolved(segment_index: int) -> void:
	if segment_index != _segment_index or _picking:
		return
	_segment_index = -1
	AudioManager.stop_ui_hover()
	hide()


func _populate(station_type: StationType) -> void:
	for panel: PanelContainer in _option_panels:
		panel.queue_free()
	_option_panels.clear()
	_focus_index = -1
	_title.text = "%s · Level %d" % [station_type.display_name, StationManager.CHOICE_LEVEL]
	_title.add_theme_color_override("font_color", station_type.color)
	for i in station_type.choice_options.size():
		var panel := _make_option(station_type.choice_options[i], station_type, i)
		_options_row.add_child(panel)
		_option_panels.append(panel)


func _make_option(perk: StationPerk, station_type: StationType, index: int) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = OPTION_SIZE
	panel.mouse_filter = Control.MOUSE_FILTER_STOP
	panel.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var style := StyleBoxFlat.new()
	style.bg_color = OPTION_FILL
	style.border_color = station_type.color
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.shadow_color = Color(0, 0, 0, 0.35)
	style.shadow_size = 8
	style.set_content_margin_all(16)
	panel.add_theme_stylebox_override("panel", style)

	var column := VBoxContainer.new()
	column.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_theme_constant_override("separation", 10)
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(column)

	if station_type.icon != null:
		var icon := TextureRect.new()
		icon.texture = station_type.icon
		icon.custom_minimum_size = Vector2(56, 56)
		icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		icon.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
		column.add_child(icon)

	var text := RichTextLabel.new()
	text.bbcode_enabled = true
	text.fit_content = true
	text.scroll_active = false
	text.custom_minimum_size = Vector2(OPTION_SIZE.x - 36, 0)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.add_theme_font_size_override("normal_font_size", 20)
	text.text = "[center]%s[/center]" % CardKeywordGlossary.to_bbcode(perk.description)
	column.add_child(text)

	panel.mouse_entered.connect(_set_focus.bind(index))
	panel.mouse_exited.connect(_on_option_mouse_exited.bind(index))
	panel.gui_input.connect(_on_option_input.bind(index))
	return panel


func _on_option_mouse_exited(index: int) -> void:
	if _focus_index == index:
		_set_focus(-1)


func _on_option_input(event: InputEvent, index: int) -> void:
	var mouse_event := event as InputEventMouseButton
	if mouse_event != null and mouse_event.pressed and mouse_event.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_pick(index)


## Keyboard and controller: left and right move focus, accept picks the focused option.
func _unhandled_input(event: InputEvent) -> void:
	if not visible or _picking or _board_view or _option_panels.is_empty():
		return
	var last := _option_panels.size() - 1
	# With nothing focused, each direction lands on the option on that side.
	if event.is_action_pressed("ui_left"):
		_set_focus(0 if _focus_index < 0 else maxi(_focus_index - 1, 0))
	elif event.is_action_pressed("ui_right"):
		_set_focus(last if _focus_index < 0 else mini(_focus_index + 1, last))
	elif event.is_action_pressed("ui_accept") and _focus_index >= 0:
		_pick(_focus_index)
	else:
		return
	get_viewport().set_input_as_handled()


## Lifts the focused option and settles the rest. -1 clears focus.
func _set_focus(index: int) -> void:
	if _picking or index == _focus_index:
		return
	_focus_index = index
	if index >= 0 and not GameManager.skip_presentation:
		AudioManager.play_ui_hover()
	else:
		AudioManager.stop_ui_hover()
	for i in _option_panels.size():
		var panel := _option_panels[i]
		panel.pivot_offset = panel.size * 0.5
		var target := Vector2.ONE * (HOVER_SCALE if i == index else 1.0)
		create_tween().tween_property(panel, "scale", target, 0.12).set_trans(Tween.TRANS_SINE)


func _pick(index: int) -> void:
	if _picking:
		return
	_picking = true
	AudioManager.stop_ui_hover()
	AudioManager.play_sfx(UISounds.CLICK)
	var picked := _option_panels[index]
	picked.pivot_offset = picked.size * 0.5
	var tween := create_tween()
	tween.set_parallel(true)
	tween.tween_property(picked, "scale", Vector2.ONE * PICK_SCALE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(
		Tween.EASE_OUT
	)
	for other: PanelContainer in _option_panels:
		if other != picked:
			tween.tween_property(other, "modulate:a", 0.0, 0.2)
	tween.chain().tween_property(self, "modulate:a", 0.0, 0.2)
	tween.chain().tween_callback(_finish_pick.bind(index))


func _finish_pick(index: int) -> void:
	hide()
	modulate.a = 1.0
	var segment_index := _segment_index
	_segment_index = -1
	StationManager.resolve_choice(segment_index, index)


func _play_intro() -> void:
	modulate.a = 1.0
	if GameManager.skip_presentation:
		return
	_dim.modulate.a = 0.0
	create_tween().tween_property(_dim, "modulate:a", 1.0, 0.2)
	_title.modulate.a = 0.0
	create_tween().tween_property(_title, "modulate:a", 1.0, 0.25)
	for i in _option_panels.size():
		var panel := _option_panels[i]
		panel.modulate.a = 0.0
		var tween := create_tween()
		tween.tween_interval(0.08 + 0.1 * i)
		tween.tween_property(panel, "modulate:a", 1.0, 0.22)


## Press to hide the options and inspect the board, press again to bring them back.
## Input passes through to the map while hidden. Does not resolve the pick.
func _set_board_view(active: bool) -> void:
	_board_view = active
	_board_view_button.text = "Show Options" if active else "Show Board"
	_dim.visible = not active
	_title.visible = not active
	_subtitle.visible = not active
	_options_row.visible = not active
	mouse_filter = Control.MOUSE_FILTER_IGNORE if active else Control.MOUSE_FILTER_STOP
