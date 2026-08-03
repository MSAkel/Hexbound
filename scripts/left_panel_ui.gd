class_name TopPanelUi
extends Control

@onready var character_name: Label = $Panel/MarginContainer/VBoxContainer/HBoxContainer/CharacterName
@onready var turn_label: Label = $Panel/MarginContainer/VBoxContainer/TurnLabel
@onready var required_score: Label = $Panel/MarginContainer/VBoxContainer/RequiredScorePanel/RequiredScore
@onready var turn_score: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TurnScoreContainer/TurnScore
@onready var turn_multi: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TurnScoreContainer/TurnMulti
@onready var total_score: Label = $Panel/MarginContainer/VBoxContainer/ScorePanel/TotalScore
@onready var selected_trigger_order_label: Label = $Panel/MarginContainer/VBoxContainer/SelectedTriggerOrderLabel
@onready var end_turn_button: Button = $Panel/MarginContainer/VBoxContainer/EndTurnButton

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	required_score.text = "%s" % [GameManager.required_score]
	character_name.text = PlayerCharacter.get_character_name(GameManager.selected_character)
	_update_trigger_order_label()
	
	Events.turn_changed.connect(_update_turn_label)
	Events.turn_score_changed.connect(_update_turn_score)
	Events.turn_multi_changed.connect(_update_turn_multi)
	Events.total_score_changed.connect(_update_total_score)
	Events.required_score_changed.connect(_update_required_score)
	Events.turn_started.connect(_on_turn_started)

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)
	end_turn_button.disabled = true

func _on_turn_started() -> void:
	end_turn_button.disabled = false

func _update_turn_label() -> void:
	turn_label.text = "Turn: %s/5" % [GameManager.current_turn]

func _update_turn_score() -> void:
	turn_score.text = "%s" % [GameManager.turn_score]

func _update_turn_multi() -> void:
	turn_multi.text = "%s" % [GameManager.turn_multi]

func _update_total_score() -> void:
	total_score.text = "%s" % [GameManager.total_score]

func _update_required_score() -> void:
	required_score.text = "%s" % [GameManager.required_score]

func _update_trigger_order_label() -> void:
	selected_trigger_order_label.text = TriggerOrderType.get_display_name(GameManager.trigger_order)
