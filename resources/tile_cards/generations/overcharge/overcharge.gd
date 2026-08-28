extends TileCard
## +60 Energy. +10% break chance after every completed trigger this turn
## Should it be a fixed break chance instead, is this card worth the risk?
const DESTROY_CHANCE_PER_TRIGGER := 0.10

var _destroy_chance_this_turn := 0.0
# Matches GameManager.turn_stamp for the turn that currently owns the stacked chance.
var _chance_turn_stamp: int = -1

func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, 60)

	# Drop last turn's stacked break chance when a new turn has started.
	if _chance_turn_stamp != GameManager.turn_stamp:
		_destroy_chance_this_turn = 0.0
		_chance_turn_stamp = GameManager.turn_stamp

	_destroy_chance_this_turn += DESTROY_CHANCE_PER_TRIGGER
	if RunRng.create_card_effect_rng(tile, self).randf() < _destroy_chance_this_turn:
		_destroy_placed_tile_card(tile, self)
		AudioManager.play_sfx(UISounds.RUNE_BREAK)


func get_board_chip(_tile: Hex = null) -> Dictionary:
	return _amount_board_chip(60, ICON_SCORE)
