# Quest slot for the quest selection screen
# Displays when the quest choices will be available to be selected and allows the player to select it
extends Panel

@onready var available_in_label: Label = $AvailableInLabel
@onready var select_new_quest_button: Button = $SelectNewQuestButton

@export var year_available: int
@export var quest_tier: Quest.QuestTier

const QUEST_UI_SCENE = preload("res://scenes/quests/quest_ui.tscn")

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
	var quest_ui = QUEST_UI_SCENE.instantiate()
	var parent = get_parent()
	var slot_index = get_index()
	quest_ui.quest_tier = quest_tier
	queue_free()  # Remove the slot first
	parent.add_child(quest_ui)  # Add the quest UI
	parent.move_child(quest_ui, slot_index)  # Move it to the correct position
	quest_ui.global_position = global_position
