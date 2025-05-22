extends Control

@onready var perks_button: TextureButton = $MarginContainer/GridContainer/PerksButton
@onready var runes_button: TextureButton = $MarginContainer/GridContainer/RunesButton
@onready var quests_button: TextureButton = $MarginContainer/GridContainer/QuestsButton

func _on_perks_button_pressed() -> void:
	UiManager.show_perks_panel.emit()

func _on_runes_button_pressed() -> void:
	UiManager.show_runes_panel.emit()

func _on_quests_button_pressed() -> void:
	UiManager.show_quests_panel.emit() 
