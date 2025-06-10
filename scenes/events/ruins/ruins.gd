class_name Ruins
extends Resource

@export var id: String
@export var ruins_name: String
@export var description: String
@export var icon: Texture2D
@export var exploration_cost: int
# should contain a list of potential rewards, each with a chance to be selected. some higher than the other
# example rewards:
# - gold
# - rune
# - perk
# - curse
# - no reward

# Reward weights (higher number = higher chance)
@export var gold_weight: int = 100
@export var insight_weight: int = 50
@export var rune_weight: int = 25
@export var perk_weight: int = 10

# Loot range for free looting
@export var min_loot_gold: int = 10
@export var max_loot_gold: int = 50

# Exploration reward ranges
@export var min_gold_reward: int = 50
@export var max_gold_reward: int = 200
@export var min_insight_reward: int = 1
@export var max_insight_reward: int = 3

# Chance to get a second reward (0.0 to 1.0)
@export var second_reward_chance: float = 0.2

# Whether this ruin can give curses (for dangerous ruins)
@export var can_give_curse: bool = false
@export var curse_weight: int = 20

func get_exploration_rewards() -> Array:
	var rewards = []
	var total_weight = gold_weight + insight_weight + rune_weight + perk_weight
	if can_give_curse:
		total_weight += curse_weight
	
	# First reward
	var roll = randf() * total_weight
	var current_weight = 0
	
	if roll < gold_weight:
		rewards.append({
			"type": "gold",
			"amount": randi_range(min_gold_reward, max_gold_reward)
		})
	elif roll < gold_weight + insight_weight:
		rewards.append({
			"type": "insight",
			"amount": randi_range(min_insight_reward, max_insight_reward)
		})
	elif roll < gold_weight + insight_weight + rune_weight:
		rewards.append({
			"type": "rune",
			"amount": 1
		})
	elif roll < gold_weight + insight_weight + rune_weight + perk_weight:
		rewards.append({
			"type": "perk",
			"amount": 1
		})
	elif can_give_curse:
		rewards.append({
			"type": "curse",
			"amount": 1
		})
	
	# Chance for second reward
	if randf() < second_reward_chance:
		roll = randf() * total_weight
		current_weight = 0
		
		if roll < gold_weight:
			rewards.append({
				"type": "gold",
				"amount": randi_range(min_gold_reward, max_gold_reward)
			})
		elif roll < gold_weight + insight_weight:
			rewards.append({
				"type": "insight",
				"amount": randi_range(min_insight_reward, max_insight_reward)
			})
		elif roll < gold_weight + insight_weight + rune_weight:
			rewards.append({
				"type": "rune",
				"amount": 1
			})
		elif roll < gold_weight + insight_weight + rune_weight + perk_weight:
			rewards.append({
				"type": "perk",
				"amount": 1
			})
		elif can_give_curse:
			rewards.append({
				"type": "curse",
				"amount": 1
			})
	
	return rewards

func get_loot_reward() -> Dictionary:
	return {
		"type": "gold",
		"amount": randi_range(min_loot_gold, max_loot_gold)
	}
