extends TileCard

const BASE_CHANCE := 0.03
const SCORE_REWARD := 500
const GOLD_REWARD := 3

# Stacks +3% after each failed roll. Resets when a reward is generated.
var current_chance: float = BASE_CHANCE

# Free activation with a 3% stackable chance to gain 500 Energy or 3 gold. Resets on success.
func _on_activate_tile_card(tile: Hex) -> void:
	var rng: RandomNumberGenerator = RunRng.create_card_effect_rng(tile, self)
	if rng.randf() < current_chance:
		if rng.randf() < 0.5:
			add_score(tile, SCORE_REWARD)
		else:
			add_gold(tile, GOLD_REWARD)
		current_chance = BASE_CHANCE
	else:
		current_chance += BASE_CHANCE


func get_board_chip(_tile: Hex = null) -> Dictionary:
	var percent := int(round(current_chance * 100.0))
	return _make_board_chip(
		BoardChipMode.CHANCE,
		"%d%%" % percent,
		null,
		get_chip_panel_color(),
		"Chance for 500 Energy or 3 Gold"
	)
