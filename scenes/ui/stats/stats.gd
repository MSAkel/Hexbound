extends Panel

## Main-menu Stats screen. Lifetime aggregates plus a Past Runs archive.
## History rows stay compact. Seed and the final board live in the detail column.

const BOARD_VIEW_SCENE := preload("res://scenes/ui/stats/run_history_board_view.tscn")

const TEXT_PRIMARY := Color("e8dfc9")
const TEXT_SECONDARY := Color("aeb9b3")
const ACCENT := Color("c29a56")
const WIN_COLOR := Color("7dcc9a")
const LOSS_COLOR := Color("e08a7a")
const ROW_BG := Color("182b30e8")
const ROW_BG_SELECTED := Color("2a454be8")
const ITEM_BORDER := Color("617575")

enum StatsTab {
	LIFETIME,
	PAST_RUNS,
}

@onready var tab_bar: TabBar = %TabBar
@onready var lifetime_scroll: ScrollContainer = %LifetimeScroll
@onready var lifetime_list: VBoxContainer = %LifetimeList
@onready var history_split: HBoxContainer = %HistorySplit
@onready var run_list: VBoxContainer = %RunList
@onready var detail_panel: VBoxContainer = %DetailPanel
@onready var empty_history_label: Label = %EmptyHistoryLabel
@onready var back_button: Button = %BackButton

var _board_view: RunHistoryBoardView = null
var _selected_index: int = -1
var _row_buttons: Array[Button] = []
var _detail_outcome: Label = null
var _detail_identity: Label = null
var _detail_stats: VBoxContainer = null
var _detail_seed: Label = null
var _copy_seed_button: Button = null
var _selected_entry: Dictionary = {}


func _ready() -> void:
	_configure_tabs()
	_build_detail_chrome()
	_show_tab(tab_bar.current_tab)
	call_deferred("_focus_stats")


func _focus_stats() -> void:
	if tab_bar != null:
		tab_bar.grab_focus()
		return
	MenuFocus.grab_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_button_pressed()


func _configure_tabs() -> void:
	tab_bar.tab_count = 2
	tab_bar.set_tab_title(StatsTab.LIFETIME, "Lifetime")
	tab_bar.set_tab_title(StatsTab.PAST_RUNS, "Past Runs")


func _build_detail_chrome() -> void:
	# Build the detail column once. Selecting a run only refreshes labels and the board.
	for child in detail_panel.get_children():
		child.queue_free()

	_detail_outcome = _make_label("Select a run", 28, TEXT_PRIMARY)
	_detail_outcome.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(_detail_outcome)

	_detail_identity = _make_label("", 18, TEXT_SECONDARY)
	_detail_identity.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	detail_panel.add_child(_detail_identity)

	_detail_stats = VBoxContainer.new()
	_detail_stats.add_theme_constant_override("separation", 4)
	detail_panel.add_child(_detail_stats)

	var seed_row := HBoxContainer.new()
	seed_row.add_theme_constant_override("separation", 8)
	detail_panel.add_child(seed_row)

	_detail_seed = _make_label("Seed —", 18, ACCENT)
	_detail_seed.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	seed_row.add_child(_detail_seed)

	_copy_seed_button = Button.new()
	_copy_seed_button.text = "Copy"
	_copy_seed_button.pressed.connect(_on_copy_seed_pressed)
	seed_row.add_child(_copy_seed_button)

	_board_view = BOARD_VIEW_SCENE.instantiate() as RunHistoryBoardView
	_board_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail_panel.add_child(_board_view)

	_set_detail_enabled(false)


func _show_tab(tab: int) -> void:
	EventBus.toggle_tooltip.emit(false, "")
	var show_lifetime := tab == StatsTab.LIFETIME
	lifetime_scroll.visible = show_lifetime
	history_split.visible = not show_lifetime
	if show_lifetime:
		_populate_lifetime()
	else:
		_populate_history()


func _populate_lifetime() -> void:
	for child in lifetime_list.get_children():
		child.queue_free()

	MetaProgressionManager.ensure_loaded()
	var stats: Dictionary = MetaProgressionManager.get_lifetime_stats_snapshot()
	var rows: Array = [
		["Runs completed", str(int(stats.get("runs_completed", 0)))],
		["Wins", str(int(stats.get("wins", 0)))],
		["Losses", str(int(stats.get("losses", 0)))],
		["Highest win difficulty", _format_difficulty_level(int(stats.get("highest_win_difficulty", 0)) - 1)],
		["Peak gold held", CountingNumber.format_int(int(stats.get("peak_gold_held", 0)))],
		["Peak gold earned in a run", CountingNumber.format_int(int(stats.get("peak_gold_earned_in_run", 0)))],
		["Peak %s in one hour" % FeastDisplay.RATING.to_lower(), CountingNumber.format_int(int(stats.get("peak_segment_score_single_turn", 0)))],
		["Peak triggers in one hour", CountingNumber.format_int(int(stats.get("peak_triggers_single_turn", 0)))],
		["Lifetime card triggers", CountingNumber.format_int(int(stats.get("total_triggers", 0)))],
	]
	for row: Array in rows:
		lifetime_list.add_child(_make_stat_row(String(row[0]), String(row[1])))


func _populate_history() -> void:
	for child in run_list.get_children():
		child.queue_free()
	_row_buttons.clear()
	_selected_index = -1
	_selected_entry.clear()

	var entries: Array = RunHistoryManager.get_entries()
	empty_history_label.visible = entries.is_empty()
	detail_panel.visible = not entries.is_empty()
	if entries.is_empty():
		_set_detail_enabled(false)
		if _board_view != null:
			_board_view.clear_board()
		return

	for index in entries.size():
		var entry: Dictionary = entries[index]
		var row := _make_run_row(entry, index)
		run_list.add_child(row)
		_row_buttons.append(row)

	_select_run(0)


func _make_run_row(entry: Dictionary, index: int) -> Button:
	var row := Button.new()
	row.toggle_mode = true
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.custom_minimum_size = Vector2(0, 56)
	row.text = _run_row_text(entry)
	row.add_theme_font_size_override("font_size", 16)
	row.add_theme_color_override("font_color", TEXT_PRIMARY)
	row.add_theme_color_override("font_hover_color", TEXT_PRIMARY)
	row.add_theme_color_override("font_pressed_color", TEXT_PRIMARY)
	row.add_theme_stylebox_override("normal", _make_row_style(ROW_BG))
	row.add_theme_stylebox_override("hover", _make_row_style(ROW_BG_SELECTED))
	row.add_theme_stylebox_override("pressed", _make_row_style(ROW_BG_SELECTED))
	row.add_theme_stylebox_override("focus", _make_row_style(ROW_BG_SELECTED))
	row.toggled.connect(func(pressed: bool) -> void:
		if pressed:
			_select_run(index)
		elif _selected_index == index:
			# Keep the active row selected when the player clicks it again.
			row.set_pressed_no_signal(true)
	)
	return row


func _run_row_text(entry: Dictionary) -> String:
	# List omits the seed. Copy lives on the selected-run detail.
	var outcome := "Victory" if bool(entry.get("is_win", false)) else "Defeat"
	var character := _character_display_name(String(entry.get("character_id", "")))
	var difficulty := Difficulty.get_level_name(int(entry.get("difficulty", 0)) as Difficulty.Level)
	var day := FeastDisplay.day_label(int(entry.get("rounds_completed", 0)))
	return "%s  ·  %s  ·  %s  ·  %s" % [outcome, character, difficulty, day]


func _select_run(index: int) -> void:
	var entries: Array = RunHistoryManager.get_entries()
	if index < 0 or index >= entries.size():
		return
	_selected_index = index
	_selected_entry = entries[index]
	for i in _row_buttons.size():
		_row_buttons[i].set_pressed_no_signal(i == index)
	_fill_detail(_selected_entry)


func _fill_detail(entry: Dictionary) -> void:
	_set_detail_enabled(true)
	var is_win := bool(entry.get("is_win", false))
	_detail_outcome.text = "Victory" if is_win else "Defeat"
	_detail_outcome.add_theme_color_override("font_color", WIN_COLOR if is_win else LOSS_COLOR)

	var character := _character_display_name(String(entry.get("character_id", "")))
	var difficulty := Difficulty.get_level_name(int(entry.get("difficulty", 0)) as Difficulty.Level)
	var day := FeastDisplay.day_label(int(entry.get("rounds_completed", 0)))
	_detail_identity.text = "%s  ·  %s  ·  %s" % [character, difficulty, day]

	for child in _detail_stats.get_children():
		child.queue_free()
	_detail_stats.add_child(_make_stat_row("Highest %s" % FeastDisplay.RATING, CountingNumber.format_int(int(entry.get("highest_round_score", 0)))))
	_detail_stats.add_child(_make_stat_row("Gold earned", CountingNumber.format_int(int(entry.get("gold_earned", 0)))))
	_detail_stats.add_child(_make_stat_row("Card triggers", CountingNumber.format_int(int(entry.get("card_triggers", 0)))))
	if bool(entry.get("is_seeded_run", false)):
		_detail_stats.add_child(_make_stat_row("Seeded run", "Yes"))

	var seed_text := String(entry.get("seed", ""))
	_detail_seed.text = "Seed  %s" % (seed_text if not seed_text.is_empty() else "—")
	_copy_seed_button.disabled = seed_text.is_empty()

	var board: Variant = entry.get("board", {})
	if board is Dictionary:
		_board_view.setup(String(entry.get("character_id", "")), board as Dictionary)
	else:
		_board_view.clear_board()


func _set_detail_enabled(enabled: bool) -> void:
	_copy_seed_button.disabled = not enabled
	if not enabled:
		_detail_outcome.text = "Select a run"
		_detail_outcome.add_theme_color_override("font_color", TEXT_PRIMARY)
		_detail_identity.text = ""
		_detail_seed.text = "Seed —"
		for child in _detail_stats.get_children():
			child.queue_free()


func _on_copy_seed_pressed() -> void:
	var seed_text := String(_selected_entry.get("seed", ""))
	if seed_text.is_empty():
		return
	DisplayServer.clipboard_set(seed_text)
	AudioManager.play_sfx(UISounds.CLICK)


func _on_tab_bar_tab_changed(tab: int) -> void:
	AudioManager.play_sfx(UISounds.SELECT)
	_show_tab(tab)


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	EventBus.toggle_tooltip.emit(false, "")
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


func _character_display_name(character_id: String) -> String:
	var definition := PlayerCharacter.get_character_by_id(character_id)
	if definition == null:
		return "Unknown"
	return definition.display_name


func _format_difficulty_level(level_index: int) -> String:
	if level_index < 0:
		return "—"
	return Difficulty.get_level_name(level_index as Difficulty.Level)


func _make_stat_row(label_text: String, value_text: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var label := _make_label(label_text, 18, TEXT_SECONDARY)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)
	var value := _make_label(value_text, 18, TEXT_PRIMARY)
	value.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	row.add_child(value)
	return row


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _make_row_style(bg: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = bg
	style.border_color = ITEM_BORDER
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 12
	style.content_margin_right = 12
	style.content_margin_top = 8
	style.content_margin_bottom = 8
	return style
