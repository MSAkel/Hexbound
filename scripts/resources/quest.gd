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
	IB,
	II,
	IIA,
	IIB,
	III,
	IIIA,
	IV,
}

# Quest choices selected at random based on the tier
# Quests will always reward 1 influence
# should be able to handle a dynamic range of objectives requirements based on difficulty
# Status changes from LOCKED to IN_PROGRESS when the player selects the quest

@export var id: String
@export var name: String
@export var objective: Array[Resource]
@export var rewards: Array[Resource]
@export var tier: QuestTier
@export status: Status
