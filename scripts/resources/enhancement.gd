class_name Enhancement
extends Resource

# Player-applied bonus attached to a placed rune. Effects are independent of the rune's
# product type, so a mult producer can receive a score enhancement and vice versa.

enum Type {
	SCORE,
	MULTIPLIER,
	GOLD,
	TRIGGER,
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var type: Type
@export_multiline var description: String
@export var short_description: String

# Bonus output resolved each time the host rune activates.
@export var score_bonus: int = 0
@export var mult_bonus: int = 0
@export var gold_bonus: int = 0
# Extra activations of the host rune (including its enhancement) before tile flow continues.
@export var trigger_count: int = 0


# Enhancement cards target occupied tiles whose rune does not already have one.
static func can_apply_to(hex: Hex) -> bool:
	if hex.active_rune == null:
		return false
	return hex.active_rune.enhancement == null


# Resolve enhancement output using the host rune's activation helpers so empower scaling applies.
func activate(host_rune: Rune, tile: Hex) -> void:
	if type == Type.SCORE:
		host_rune.add_score(tile, score_bonus)
	if type == Type.MULTIPLIER:
		host_rune.add_multiplier(tile, mult_bonus)
	if type == Type.GOLD:
		host_rune.add_gold(tile, gold_bonus)
	if type == Type.TRIGGER:
		var retriggers: Array[Rune] = []
		retriggers.resize(trigger_count)
		retriggers.fill(host_rune)
		host_rune.queue_rune_triggers(tile, retriggers)
