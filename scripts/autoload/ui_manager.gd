extends CanvasLayer

signal show_runes_panel
signal show_runes_choice_panel
signal show_cards_choice_panel

var active_panel: Control = null

func show_panel(panel: Control) -> void:
	if active_panel != null:
		active_panel.hide()
	active_panel = panel
	panel.show()
