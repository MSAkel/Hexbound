class_name Quest
extends Resource

enum Status {
	LOCKED,
	IN_PROGRESS,
	COMPLETED,
	FAILED
}

enum QuestTier {
	I,
	IA,
	II,
	IIA,
	III,
	IIIA,
	IV,
}

# Quest choices selected at random based on the tier
# Quests will always reward 1 influence
# should be able to handle a dynamic range of objectives requirements based on difficulty
# Status changes from LOCKED to IN_PROGRESS when the player selects the quest
# Quest objectives can include exploration, buildings, goods, etc.
# Quest rewards can include influence, goods, buildings, runes.
@export var id: String
@export var name: String
@export var objective: Array[Objective]
@export var rewards: Array[Reward]
@export var tier: QuestTier

var status: Status = Status.LOCKED
