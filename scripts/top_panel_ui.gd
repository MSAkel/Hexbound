class_name TopPanelUi
extends Control


@onready var year_label: Label = $Panel/MarginContainer/VBoxContainer/YearLabel

@onready var regular_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/RegularGameSpeedButton
@onready var double_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/DoubleGameSpeedButton
@onready var triple_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/TripleGameSpeedButton

@onready var goods_container: HBoxContainer = $Panel/MarginContainer/GoodsContainer
@onready var influence_progress: Label = $Panel/MarginContainer/InfluenceProgress

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")
const GOOD_UI = preload("res://scenes/goods/good_ui.tscn")


func _ready() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]
	Events.turn_started.connect(_update_ui)

	Events.influence_changed.connect(_update_influence_progress)

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

func _update_ui() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]

func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)

func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)

func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)

func _update_influence_progress() -> void:
	influence_progress.text = "Influence: %s / %s" % [GameManager.influence_progress, GameManager.influence_required]
