extends Control

@onready var panel: Panel = $Panel
@onready var choices_container: HBoxContainer = $Panel/ChoicesContainer
@onready var reroll_button: Button = $Panel/RerollButton

func _ready() -> void:
	hide()
	UiManager.show_runes_panel.connect(_on_show_panel)

func _on_show_panel() -> void:
	UiManager.show_panel(self)

func _on_close_button_pressed() -> void:
	hide()

func _on_reroll_button_pressed() -> void:
	pass
