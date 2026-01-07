extends Control


@onready var close_button: TextureButton = $Panel/CloseButton
@onready var title: Label = $Panel/MarginContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/Title
@onready var description: Label = $Panel/MarginContainer/VBoxContainer/Panel/MarginContainer/VBoxContainer/Description

@onready var explore_rewards_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/RewardsContainer/FirstOptionPanel/MarginContainer/ExploreRewardsContainer
@onready var loot_rewards_container: HBoxContainer = $Panel/MarginContainer/VBoxContainer/RewardsContainer/SecondOptionPanel/MarginContainer/LootRewardsContainer

@onready var explore_button: Button = $Panel/MarginContainer/VBoxContainer/RewardsContainer/FirstOptionPanel/MarginContainer/ExploreButton
@onready var loot_button: Button = $Panel/MarginContainer/VBoxContainer/RewardsContainer/SecondOptionPanel/MarginContainer/LootButton



func _on_loot_button_pressed() -> void:
	pass # Replace with function body.


func _on_explore_button_pressed() -> void:
	pass # Replace with function body.


func _on_close_button_pressed() -> void:
	hide()
