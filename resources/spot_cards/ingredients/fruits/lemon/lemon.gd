extends TileCard
## +8 Flavour. If this activation is Doubled, also +3 Mult. Double already doubles the Flavour.

const EMPOWERED_MULT := 3.0


func _on_activate_tile_card(tile: Hex) -> void:
	add_flavour(tile, _get_production_amount())
	if not _activation_was_empowered:
		return
	# Flat Mult identity. Do not scale it with Empower's Energy double.
	add_additive_mult(tile, EMPOWERED_MULT, false)
