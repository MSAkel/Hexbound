extends CanvasLayer

signal show_perks_panel
signal show_runes_panel
signal show_quests_panel
signal show_buildings_choice_panel
signal show_runes_choice_panel

var active_panel: Control = null

func _ready() -> void:
	pass

func show_panel(panel: Control) -> void:
	if active_panel != null:
		active_panel.hide()
	active_panel = panel
	panel.show()
