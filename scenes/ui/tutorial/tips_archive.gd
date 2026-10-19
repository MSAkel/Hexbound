class_name TipsArchive
extends Control

## Every tutorial hint the player has seen, readable again. Unseen ones show as "???".
## Opened from the pause menu and the main menu.

signal closed

const PANEL_COLOR := Color(0.07, 0.11, 0.09, 0.98)
const BORDER_COLOR := Color("#6fdc9c")
const TITLE_COLOR := Color("#ffd166")
const MUTED_COLOR := Color(0.62, 0.7, 0.66)
const LOCKED_TEXT := "???"

var _list: VBoxContainer
var _detail_title: Label
var _detail_body: RichTextLabel
var _count_label: Label
var _close_button: Button
var _selected_id: StringName = &""
## Row button per hint id from the last rebuild, so focus can follow the selection.
var _row_buttons: Dictionary = {}


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_build_ui()
	add_to_group(InputManager.MENU_GROUP)
	visibility_changed.connect(_on_visibility_changed)
	TutorialManager.progress_changed.connect(_on_progress_changed)


func _on_visibility_changed() -> void:
	if not visible:
		return
	_rebuild_list()
	_close_button.grab_focus.call_deferred()


## InputManager menu hook. The selected row, else Close.
func focus_default() -> void:
	var row: Button = _row_buttons.get(_selected_id)
	if row != null and is_instance_valid(row):
		row.grab_focus()
	else:
		_close_button.grab_focus()


func _on_progress_changed() -> void:
	if visible:
		_rebuild_list()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		_on_close_pressed()


func _on_close_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	closed.emit()


func _rebuild_list() -> void:
	# Rebuilding frees the focused row. Put focus back on the same hint afterwards.
	var focus := get_viewport().gui_get_focus_owner()
	var refocus := focus != null and _list.is_ancestor_of(focus)
	_row_buttons.clear()
	for child in _list.get_children():
		_list.remove_child(child)
		child.queue_free()
	var seen_count := 0
	var total := 0
	var first_seen: StringName = &""
	for category: String in TutorialHints.CATEGORIES:
		var header := Label.new()
		header.text = category.to_upper()
		header.add_theme_font_size_override("font_size", 16)
		header.add_theme_color_override("font_color", BORDER_COLOR)
		_list.add_child(header)
		for id: StringName in TutorialHints.all_ids():
			var def := TutorialHints.get_def(id)
			if def.get("category", "") != category:
				continue
			total += 1
			var seen := TutorialManager.has_seen_any(id)
			if seen:
				seen_count += 1
				if first_seen == &"":
					first_seen = id
			var button := Button.new()
			button.text = String(def.get("title", "")) if seen else LOCKED_TEXT
			button.alignment = HORIZONTAL_ALIGNMENT_LEFT
			button.flat = true
			button.add_theme_font_size_override("font_size", 20)
			if id == _selected_id:
				button.add_theme_color_override("font_color", TITLE_COLOR)
			elif not seen:
				button.add_theme_color_override("font_color", MUTED_COLOR)
			button.pressed.connect(_select.bind(id))
			button.mouse_entered.connect(AudioManager.play_ui_hover)
			button.focus_entered.connect(AudioManager.play_ui_hover)
			_list.add_child(button)
			_row_buttons[id] = button
	_count_label.text = "%d / %d found" % [seen_count, total]
	if _selected_id == &"" or not TutorialHints.has(_selected_id):
		_selected_id = first_seen
		if _selected_id != &"":
			# Recolour the newly selected row.
			_rebuild_list.call_deferred()
	_show_detail(_selected_id)
	if refocus:
		focus_default()


func _select(id: StringName) -> void:
	AudioManager.play_sfx(UISounds.SELECT)
	_selected_id = id
	_rebuild_list()


func _show_detail(id: StringName) -> void:
	if id == &"":
		_detail_title.text = "No tips yet"
		_detail_body.text = "Tips appear as you play. Each one you see is saved here."
		return
	var def := TutorialHints.get_def(id)
	if not TutorialManager.has_seen_any(id):
		_detail_title.text = LOCKED_TEXT
		_detail_body.text = "Keep playing to find this tip."
		return
	_detail_title.text = String(def.get("title", ""))
	_detail_body.text = TutorialHints.to_bbcode(String(def.get("body", "")))


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.color = Color(0, 0, 0, 0.72)
	backdrop.set_anchors_preset(Control.PRESET_FULL_RECT)
	backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(backdrop)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(center)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(1040, 640)
	var style := StyleBoxFlat.new()
	style.bg_color = PANEL_COLOR
	style.border_color = BORDER_COLOR
	style.set_border_width_all(3)
	style.set_corner_radius_all(14)
	style.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", style)
	center.add_child(panel)

	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	panel.add_child(column)

	var header := HBoxContainer.new()
	column.add_child(header)
	var title := Label.new()
	title.text = "Tips"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_font_size_override("font_size", 40)
	title.add_theme_color_override("font_color", TITLE_COLOR)
	header.add_child(title)
	_count_label = Label.new()
	_count_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_count_label.add_theme_font_size_override("font_size", 18)
	_count_label.add_theme_color_override("font_color", MUTED_COLOR)
	header.add_child(_count_label)

	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 28)
	column.add_child(body)

	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(340, 0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	body.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 2)
	scroll.add_child(_list)

	body.add_child(VSeparator.new())

	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 14)
	body.add_child(detail)
	_detail_title = Label.new()
	_detail_title.add_theme_font_size_override("font_size", 30)
	_detail_title.add_theme_color_override("font_color", TITLE_COLOR)
	detail.add_child(_detail_title)
	_detail_body = RichTextLabel.new()
	_detail_body.bbcode_enabled = true
	_detail_body.fit_content = true
	_detail_body.scroll_active = false
	_detail_body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail_body.add_theme_font_size_override("normal_font_size", 24)
	detail.add_child(_detail_body)

	_close_button = Button.new()
	_close_button.text = "Close"
	_close_button.custom_minimum_size = Vector2(140, 44)
	_close_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_close_button.pressed.connect(_on_close_pressed)
	_close_button.mouse_entered.connect(AudioManager.play_ui_hover)
	column.add_child(_close_button)
