class_name TopPanelUi
extends Control


@onready var year_label: Label = $Panel/MarginContainer/VBoxContainer/YearLabel
@onready var victory_points: Label = $Panel/MarginContainer/VictoryPoints

@onready var gold_count: Label = $Panel/MarginContainer/HBoxContainer/GoldContainer/GoldCount
@onready var favor_count: Label = $Panel/MarginContainer/HBoxContainer/FavorContainer/FavorCount
@onready var insight_count: Label = $Panel/MarginContainer/HBoxContainer/InsightContainer/InsightCount

@onready var regular_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/RegularGameSpeedButton
@onready var double_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/DoubleGameSpeedButton
@onready var triple_game_speed_button: Button = $Panel/MarginContainer/VBoxContainer/GameSpeedContainer/TripleGameSpeedButton

const UI_SOUNDS = preload("res://scripts/resources/ui_sounds.gd")

func _ready() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]
	Events.turn_started.connect(_update_ui)
	Events.gold_changed.connect(_on_gold_changed)

func _on_end_turn_button_pressed() -> void:
	Events.turn_ended.emit()
	AudioManager.play_ui_sound(UI_SOUNDS.END_TURN)

func _process(_delta: float) -> void:
	pass

func _update_ui() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]

	# gold_count.text = "%s" % [GameManager.gold_count]
	favor_count.text = "%s" % [GameManager.favor_count]
	insight_count.text = "%s" % [GameManager.insight_count]

func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)

func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)

func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)

func _on_gold_changed(new_amount: int) -> void:
	gold_count.text = "%s" % [new_amount]
