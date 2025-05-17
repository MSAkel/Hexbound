class_name TopPanelUi
extends Control

# var year = 1
@onready var year_label: Label = $MarginContainer/Panel/YearLabel
@onready var gold_count: Label = $MarginContainer/HBoxContainer/GoldContainer/GoldCount
@onready var food_count: Label = $MarginContainer/HBoxContainer/FoodContainer/FoodCount

func _ready() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]

# func on_turn_end() -> void:
# 	year += 1
# 	year_label.text = "Year: %s" % [year]


func _on_end_turn_button_pressed() -> void:
	GameManager.turn_ended.emit()
	GameManager.end_turn()
	year_label.text = "Year: %s" % [GameManager.current_year]
	gold_count.text = "%s" % [GameManager.gold_count]
	food_count.text = "%s" % [GameManager.food_count]
	# on_turn_end()
