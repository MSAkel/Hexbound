extends Panel

func _ready() -> void:
	UiManager.show_quests_panel.connect(self._on_show_quests_panel)

func _on_show_quests_panel() -> void:
	show()

func _on_close_button_pressed() -> void:
	hide()
