extends Rune

func _on_activate_rune(tile: Hex) -> void:
	GameManager.turn_multi += score_value
	create_floating_text(tile, "+%d score" % score_value)
