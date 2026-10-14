extends TileCard
## +8 Flavour. If this activation is Garnished, also +3 Mult. Garnish already doubles the Flavour.

const GARNISHED_MULT := 3.0


func _on_activate_tile_card(tile: Hex) -> void:
	add_flavour(tile, _get_production_amount())
	if not _activation_was_garnished:
		return
	# Flat Mult identity. Do not scale it with Garnish's output scale.
	add_additive_mult(tile, GARNISHED_MULT, false)
