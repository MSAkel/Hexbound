extends Control

@onready var panel: Panel = $Panel
@onready var quests_grid_container: GridContainer = $Panel/QuestsGridContainer

func _ready() -> void:
	hide()  # Start hidden
	UiManager.show_quests_panel.connect(_on_show_panel)

func _on_show_panel() -> void:
	UiManager.show_panel(self)

func _on_close_button_pressed() -> void:
	hide()
