extends PanelContainer

const UI_SOUNDS = preload("uid://ga4itha1r32r")

func _ready() -> void:
	UiManager.show_warning_panel.connect(_on_show_warning_panel)

func _on_show_warning_panel() -> void:
	UiManager.show_panel(self)

func _on_yes_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)
	hide()


func _on_no_button_pressed() -> void:
	hide()
