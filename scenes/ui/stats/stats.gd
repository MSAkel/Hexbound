extends Panel

## Main-menu Stats screen. Lifetime aggregates.

const TEXT_PRIMARY := Color("e8dfc9")
const TEXT_SECONDARY := Color("aeb9b3")

@onready var lifetime_list: VBoxContainer = %LifetimeList
@onready var back_button: Button = %BackButton


func _ready() -> void:
	add_to_group(InputManager.MENU_GROUP)
	_populate_lifetime()
	call_deferred("_focus_stats")


func _focus_stats() -> void:
	MenuFocus.grab_first(self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		var viewport := get_viewport()
		if viewport != null:
			viewport.set_input_as_handled()
		_on_back_button_pressed()


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
		["Peak %s in one hour" % GameTerms.RATING.to_lower(), CountingNumber.format_int(int(stats.get("peak_segment_score_single_turn", 0)))],
		[CardKeywordGlossary.to_plain("Peak {triggers} in one hour"),CountingNumber.format_int(int(stats.get("peak_triggers_single_turn", 0)))],
		[CardKeywordGlossary.to_plain("Lifetime card {triggers}"),CountingNumber.format_int(int(stats.get("total_triggers", 0)))],
	]
	for row: Array in rows:
		lifetime_list.add_child(_make_stat_row(String(row[0]), String(row[1])))


func _on_back_button_pressed() -> void:
	AudioManager.play_sfx(UISounds.CLICK)
	EventBus.toggle_tooltip.emit(false, "")
	get_tree().change_scene_to_file(ScenePaths.MAIN_MENU)


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
