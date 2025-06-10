class_name Reward
extends Resource

enum RewardType {
	INFLUENCE,
	GOOD,
	BUILDING,
	RUNE,
}

@export var reward: Resource
@export var amount: int
@export var type: RewardType
@export_multiline var description: String


func process_rewards() -> void:
	match type:
		Reward.RewardType.INFLUENCE:
			GameManager.influence_progress += amount
		Reward.RewardType.GOOD:
			GoodsManager.add_good(reward, amount)
		Reward.RewardType.BUILDING:
			Events.building_selected.emit(reward as Building)
		Reward.RewardType.RUNE:
			Events.rune_selected.emit(reward as Rune)
