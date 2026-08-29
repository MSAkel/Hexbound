extends TileCard
## +8 Energy. If this activation is Empowered, also +4 Mult. Empower already doubles the Energy.

const EMPOWERED_MULT := 4.0


func _on_activate_tile_card(tile: Hex) -> void:
	add_score(tile, _get_production_amount())
	if not _activation_was_empowered:
		return
	# Flat Mult identity. Do not scale it with Empower's Energy double.
	add_multiplier(tile, EMPOWERED_MULT, false)
