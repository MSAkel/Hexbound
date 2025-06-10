class_name QuestUI
extends Panel

@onready var quest_name: Label = $MarginContainer/VBoxContainer/QuestName
@onready var objectives_containter: HBoxContainer = $MarginContainer/VBoxContainer/ObjectivesMarginPanel/ObjectivesContainter
@onready var rewards_container: HBoxContainer = $MarginContainer/VBoxContainer/RewardsMarginPanel/RewardsContainer
@onready var complete_quest_button: Button = $MarginContainer/VBoxContainer/CompleteQuestButton
@onready var objectives_lable: Label = $MarginContainer/VBoxContainer/ObjectivesMarginPanel/ObjectivesLable

const OBJECTIVE_UI_SCENE = preload("res://scenes/quests/objective_ui.tscn")
const REWARD_UI_SCENE = preload("res://scenes/quests/reward_ui.tscn")

var current_quest: Quest
var quest_tier: Quest.QuestTier

# The current functionality is to load a random quest from the quests folder
# This will be replaced with a more dynamic quest selection system, allowing the player to select a quest from a list of quests

func _ready() -> void:
	_load_random_quest()
	Events.quest_progress_updated.connect(_check_objectives_completion)

func _load_random_quest() -> void:
	var quest_files = _get_quest_files()
	if quest_files.is_empty():
		push_error("No quest files found for tier %s!" % quest_tier)
		return
		
	var random_quest = load(quest_files.pick_random()) as Quest
	if random_quest:
		current_quest = random_quest
		quest_name.text = random_quest.name
		_display_objectives()
		_display_rewards()
		_check_objectives_completion()

func _display_objectives() -> void:
	for objective in current_quest.objective:
		var objective_ui = OBJECTIVE_UI_SCENE.instantiate()
		objectives_containter.add_child(objective_ui)
		objective_ui.objective = objective

func _display_rewards() -> void:
	for reward in current_quest.rewards:
		var reward_ui = REWARD_UI_SCENE.instantiate()
		rewards_container.add_child(reward_ui)
		reward_ui.amount_label.text = str(reward.amount)
		reward_ui.icon.texture = reward.reward.icon

func _get_quest_files() -> Array:
	var quest_files = []
	var dir = DirAccess.open("res://resources/quests")
	if dir:
		dir.list_dir_begin()
		var file_name = dir.get_next()
		while file_name != "":
			if file_name.ends_with(".tres"):
				var quest = load("res://resources/quests/" + file_name) as Quest
				if quest and quest.tier == quest_tier:
					quest_files.append("res://resources/quests/" + file_name)
			file_name = dir.get_next()
	return quest_files

func _check_objectives_completion() -> void:
	if not current_quest:
		return
		
	var all_completed = true
	for objective in current_quest.objective:
		if not objective.completed:
			all_completed = false
			break
	
	complete_quest_button.disabled = not all_completed

func _on_complete_quest_button_pressed() -> void:
	objectives_containter.hide()
	objectives_lable.text = "Completed"
	complete_quest_button.hide()

	# Clean up objectives first
	for objective in current_quest.objective:
		objective.cleanup()

	# Then process rewards
	for reward in current_quest.rewards:
		reward.process_rewards()
	
	current_quest.status = Quest.Status.COMPLETED
	GameManager.influence_progress += 1
