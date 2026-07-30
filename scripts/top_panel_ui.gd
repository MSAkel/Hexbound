class_name TopPanelUi
extends Control

@onready var character_name: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CharacterName
@onready var year_label: Label = $Panel/MarginContainer/VBoxContainer/YearLabel
@onready var influence_progress: Label = $Panel/MarginContainer/VBoxContainer/InfluenceProgress
@onready var required_influence: Label = $Panel/MarginContainer/VBoxContainer/RequiredInfluence

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]
	required_influence.text = "%s" % [GameManager.influence_required]
	character_name.text = PlayerCharacter.get_character_name(GameManager.selected_character)
	
	Events.turn_started.connect(_update_ui)
	Events.influence_changed.connect(_update_influence_progress)

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)


func _update_ui() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]

func _update_influence_progress() -> void:
	influence_progress.text = "%s" % [GameManager.influence_progress]
	required_influence.text = "%s" % [GameManager.influence_required]
