extends TileCard

const BASE_CHANCE := 0.03
const SCORE_REWARD := 400
const GOLD_REWARD := 8

# Stacks +3% after each failed roll. Resets when a reward is generated.
var current_chance: float = BASE_CHANCE

# Free activation with a 3% stackable chance to gain 400 Energy or 8 Gold. Resets on success.
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
		_create_floating_text(
			tile,
			"+%d%%" % int(round(BASE_CHANCE * 100.0))
		)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	var percent := int(round(current_chance * 100.0))
	return _make_board_chip(
		BoardChipMode.CHANCE,
		"%d%%" % percent,
		null,
		get_chip_panel_color(),
		"Chance for 400 Energy or 8 Gold"
	)


func capture_placed_save_state() -> Dictionary:
	return {"current_chance": current_chance}


func apply_placed_save_state(data: Dictionary) -> void:
	current_chance = float(data.get("current_chance", BASE_CHANCE))
