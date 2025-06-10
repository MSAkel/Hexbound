class_name RuinsUI
extends Control

@onready var description_panel: Panel = $Container/DescriptionPanel
@onready var ruins_name: Label = $Container/DescriptionPanel/MarginContainer/VBoxContainer/RuinsName
@onready var description: Label = $Container/DescriptionPanel/MarginContainer/VBoxContainer/Description
@onready var ruins_button: TextureButton = $Container/RuinsButton

@onready var explore_button: Button = $Container/DescriptionPanel/MarginContainer/VBoxContainer/ButtonsContainer/ExploreButton
@onready var loot_button: Button = $Container/DescriptionPanel/MarginContainer/VBoxContainer/ButtonsContainer/LootButton

# @onready var results_panel: Panel = $Container/ResultsPanel
# @onready var results_label: Label = $Container/ResultsPanel/MarginContainer/VBoxContainer/ResultsLabel
# @onready var close_results_button: Button = $Container/ResultsPanel/MarginContainer/VBoxContainer/CloseButton

var map: HexTileMap
var center_coordinates: Vector2i
var tile: Hex
var ruins: Ruins = null

func _ready() -> void:
	pass
	# results_panel.hide()

func _on_ruins_button_pressed() -> void:
	description_panel.show()

func _on_close_button_pressed() -> void:
	description_panel.hide()

func _on_explore_button_pressed() -> void:
	if GameManager.gold < ruins.exploration_cost:
		# TODO: Show "not enough gold" message
		return
		
	GameManager.gold -= ruins.exploration_cost
	var rewards = ruins.get_exploration_rewards()
	
	var result_text = "Exploration Results:\n\n"
	for reward in rewards:
		match reward.type:
			"gold":
				GameManager.gold += reward.amount
				result_text += "Found %d gold!\n" % reward.amount
			"insight":
				GameManager.insight += reward.amount
				result_text += "Gained %d insight!\n" % reward.amount
			"rune":
				# TODO: Implement rune reward
				result_text += "Found a mysterious rune!\n"
			"perk":
				# TODO: Implement perk reward
				result_text += "Discovered a new perk!\n"
			"curse":
				# TODO: Implement curse system
				result_text += "A curse has been placed upon you!\n"
	
	# results_label.text = result_text
	# description_panel.hide()
	# results_panel.show()

func _on_loot_button_pressed() -> void:
	var reward = ruins.get_loot_reward()
	GameManager.gold += reward.amount
	
	var result_text = "Loot Results:\n\n"
	result_text += "Found %d gold!" % reward.amount
	
	# results_label.text = result_text
	# description_panel.hide()
	# results_panel.show()

# func _on_close_results_button_pressed() -> void:
# 	results_panel.hide()
	# TODO: Mark the ruins as completed and update the map
