extends Rune

const BASE_CHANCE := 0.03
const SCORE_REWARD := 500
const GOLD_REWARD := 20

# Stacks +3% after each failed roll; resets when a reward is generated.
var current_chance: float = BASE_CHANCE

# Spends 1 gold and gains a 3% stackable chance to either gain 500 score or 20 gold. Resets on generation
func _on_activate_rune(tile: Hex) -> void:
	if not GoldManager.can_afford(1):
		create_floating_text(tile, "Insufficient gold")
		return

	GoldManager.remove(1)

	if randf() < current_chance:
		if randf() < 0.5:
			add_score(tile, SCORE_REWARD)
		else:
			add_gold(tile, GOLD_REWARD)
		current_chance = BASE_CHANCE
	else:
		current_chance += BASE_CHANCE
