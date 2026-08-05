extends Control

@onready var played_as_label: Label = $background/StatsPanel/MarginContainer/VBoxContainer/PlayedAsLabel
@onready var turns_played_label: Label = $background/StatsPanel/MarginContainer/VBoxContainer/TurnsPlayedLabel
@onready var gold_earned_label: Label = $background/StatsPanel/MarginContainer/VBoxContainer/GoldEarnedLabel
@onready var cards_played_label: Label = $background/StatsPanel/MarginContainer/VBoxContainer/CardsPlayedLabel

const UI_SOUNDS := preload("res://scripts/resources/ui_sounds.gd")


func _ready() -> void:
	hide()
	Events.all_challenges_completed.connect(_on_all_challenges_completed)


func _on_all_challenges_completed() -> void:
	played_as_label.text = PlayerCharacter.get_character_name(GameManager.selected_character)
	turns_played_label.text = "Phase Reached: %s" % GameManager.current_phase
	gold_earned_label.text = "Gold Earned: %s" % GoldManager.amount
	cards_played_label.text = "Total Score: %s" % GameManager.total_score
	UiManager.show_panel(self)


func _on_continue_pressed() -> void:
	hide()
	if UiManager.active_panel == self:
		UiManager.active_panel = null
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	GameManager.continue_run_after_victory()


func _on_main_menu_pressed() -> void:
	AudioManager.play_ui_sound(UI_SOUNDS.CLICK)
	get_tree().change_scene_to_file("res://scenes/ui/main_menu/main_menu.tscn")
