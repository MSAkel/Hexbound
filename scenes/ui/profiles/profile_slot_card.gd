class_name ProfileSlotCard
extends PanelContainer

## One profile slot on the profile panel: a summary of a filled slot (ProfileManager.slot_summary),
## or "New profile" for an empty one.

signal select_pressed(slot: int)
signal delete_pressed(slot: int)
signal unlock_all_pressed(slot: int)

@onready var title_label: Label = %SlotTitle
@onready var active_tag: Label = %ActiveTag
@onready var details_label: Label = %Details
@onready var run_tag: Label = %RunTag
@onready var unlocked_tag: Label = %UnlockedTag
@onready var select_button: Button = %SelectButton
@onready var unlock_all_button: Button = %UnlockAllButton
@onready var delete_button: Button = %DeleteButton

var slot := 1


func _ready() -> void:
	select_button.pressed.connect(func() -> void: select_pressed.emit(slot))
	delete_button.pressed.connect(func() -> void: delete_pressed.emit(slot))
	unlock_all_button.pressed.connect(func() -> void: unlock_all_pressed.emit(slot))


func refresh() -> void:
	var summary := ProfileManager.slot_summary(slot)
	var is_active := slot == ProfileManager.active_slot
	var unlocked := ProfileManager.is_unlock_all() if is_active else bool(summary.get("unlock_all", false))
	title_label.text = "Profile %d" % slot
	active_tag.visible = is_active
	run_tag.visible = bool(summary.get("has_run", false))
	unlocked_tag.visible = unlocked
	details_label.text = _details_text(summary)
	select_button.disabled = is_active
	select_button.text = "Selected" if is_active else "Select"
	delete_button.visible = not summary.is_empty()
	unlock_all_button.visible = is_active and not unlocked


func _details_text(summary: Dictionary) -> String:
	if summary.is_empty():
		return "New profile"
	var lines: Array[String] = []
	var last_played := int(summary["last_played"])
	if last_played > 0:
		lines.append("Last played %s" % Time.get_date_string_from_unix_time(last_played))
	lines.append("Play time %s" % _play_time_text(float(summary["play_time"])))
	var wins := int(summary["wins"])
	lines.append("%d %s" % [wins, "win" if wins == 1 else "wins"])
	var top_win := int(summary["highest_win_difficulty"])
	lines.append("Highest win: Level %d" % top_win if top_win > 0 else "No wins yet")
	lines.append("Top chef level %d" % int(summary["top_chef_level"]))
	return "\n".join(lines)


static func _play_time_text(seconds: float) -> String:
	var minutes := int(seconds / 60.0)
	if minutes < 60:
		return "%dm" % minutes
	return "%dh %02dm" % [minutes / 60, minutes % 60]
