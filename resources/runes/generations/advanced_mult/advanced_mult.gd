extends Rune

# +4 Mult increased by 1 for each Mult rune on the same segment
func _on_activate_rune(_tile: Hex) -> void:
	var producer_count = _get_all_runes_on_same_segment(_tile, Rune.RuneType.PRODUCER).size()
	add_multiplier(_tile, producer_count + base_production_amount)
