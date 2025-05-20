extends TextureButton

func _on_pressed() -> void:
	print("quests button pressed")
	UiManager.show_quests_panel.emit()
