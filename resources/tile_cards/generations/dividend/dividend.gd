extends TileCard

const VEST_TRIGGERS := 4

# Rare gold vest. Pays stored production every 4th trigger.
func _on_activate_tile_card(tile: Hex) -> void:
	activation_count += 1
	if activation_count % VEST_TRIGGERS != 0:
		return
	add_gold(tile, _get_production_amount())
	_create_floating_text(tile, "Dividend!")


func get_board_chip(_tile: Hex = null) -> Dictionary:
	var charged := activation_count % VEST_TRIGGERS
	return _make_board_chip(
		BoardChipMode.PROGRESS,
		"%d/%d" % [charged, VEST_TRIGGERS],
		ICON_GOLD,
		get_chip_panel_color(),
		"+%d Gold every %d triggers" % [_get_production_amount(), VEST_TRIGGERS]
	)
