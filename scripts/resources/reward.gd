class_name Reward
extends Resource

enum RewardType {
	SCORE,
	GOLD,
	RUNE,
}

@export var reward: Resource
@export var amount: int
@export var type: RewardType
@export_multiline var description: String


func process_rewards() -> void:
	match type:
		Reward.RewardType.SCORE:
			GameManager.turn_score += amount
		Reward.RewardType.GOLD:
			GoldManager.add(amount)
		Reward.RewardType.RUNE:
			Events.rune_selected.emit(reward as Rune)
