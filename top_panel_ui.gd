class_name TopPanelUi
extends Control


@onready var year_label: Label = $Panel/MarginContainer/VBoxContainer/YearLabel
@onready var victory_points: Label = $Panel/MarginContainer/VBoxContainer/VictoryPoints

@onready var gold_count: Label = $Panel/MarginContainer/HBoxContainer/GoldContainer/GoldCount
@onready var food_count: Label = $Panel/MarginContainer/HBoxContainer/FoodContainer/FoodCount

@onready var nature_essence_count: Label = $Panel/MarginContainer/EssencesContainer/NatureEssence/NatureEssenceCount
@onready var fire_essence_count: Label = $Panel/MarginContainer/EssencesContainer/FireEssence/FireEssenceCount
@onready var frost_essence_count: Label = $Panel/MarginContainer/EssencesContainer/FrostEssence/FrostEssenceCount
@onready var storm_essence_count: Label = $Panel/MarginContainer/EssencesContainer/StormEssence/StormEssenceCount

@onready var regular_game_speed_button: TextureButton = $GameSpeedContainer/RegularGameSpeedButton
@onready var double_game_speed_button: Button = $GameSpeedContainer/DoubleGameSpeedButton
@onready var triple_game_speed_button: Button = $GameSpeedContainer/TripleGameSpeedButton

@onready var end_turn_audio: AudioStreamPlayer2D = $EndTurnAudio

func _ready() -> void:
	year_label.text = "Year: %s" % [GameManager.current_year]

func _on_end_turn_button_pressed() -> void:
	GameManager.turn_ended.emit()
	end_turn_audio.play()
	year_label.text = "Year: %s" % [GameManager.current_year]

func _process(delta: float) -> void:
	nature_essence_count.text = "%s" % [GameManager.nature_essence]
	fire_essence_count.text = "%s" % [GameManager.fire_essence]
	frost_essence_count.text = "%s" % [GameManager.frost_essence]
	storm_essence_count.text = "%s" % [GameManager.storm_essence]

	gold_count.text = "%s" % [GameManager.gold_count]
	food_count.text = "%s" % [GameManager.food_count]



func _on_regular_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(1.0)

func _on_double_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(2.0)

func _on_triple_game_speed_button_pressed() -> void:
	GameManager.set_game_speed(3.0)
