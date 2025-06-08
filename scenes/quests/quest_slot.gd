# Quest slot for the quest selection screen
# Displays when the quest choices will be available to be selected and allows the player to select it
extends Panel

@onready var available_in_label: Label = $AvailableInLabel
@onready var select_new_quest_button: Button = $SelectNewQuestButton

@export var year_available: int

func _ready() -> void:
	available_in_label.text = "Available on year %s" % year_available
	select_new_quest_button.text = "Select New Quest"
	select_new_quest_button.disabled = true
	select_new_quest_button.visible = false

	Events.turn_started.connect(_update_slot_status)


func _update_slot_status() -> void:
	if GameManager.current_year >= year_available:
		available_in_label.visible = false
		select_new_quest_button.disabled = false
		select_new_quest_button.visible = true

func _on_select_new_quest_button_pressed() -> void:
	pass
