extends MealCard

## +1 Gold after 10 run-wide card fires. When Coffee pays, any fires beyond the
## threshold are discarded instead of being carried into the next payout.

const FIRES_PER_GOLD := 10
const GOLD_PER_PAYOUT := 1

var last_payout_fire_total: int = 0


func _on_activate_tile_card(tile: Hex) -> void:
	if _fires_since_last_payout() < FIRES_PER_GOLD:
		failed_tile_card_text(tile)
		return

	add_gold(tile, GOLD_PER_PAYOUT)
	# Anchor the next threshold to this fire. This is what prevents excess
	# accumulated fires from stacking or carrying over.
	last_payout_fire_total = RunLedger.total_fires
	RunLedger.record_dish_plated()


func get_board_chip(_tile: Hex = null) -> Dictionary:
	var progress := mini(_fires_since_last_payout(), FIRES_PER_GOLD)
	var chip := _make_board_chip(
		BoardChipMode.PROGRESS,
		"%d/%d" % [progress, FIRES_PER_GOLD],
		ICON_FIRE,
		get_chip_panel_color(),
		"Fires until +%d Gold" % GOLD_PER_PAYOUT
	)
	chip["extra_icon"] = ICON_GOLD
	return chip


func capture_placed_save_state() -> Dictionary:
	return {"last_payout_fire_total": last_payout_fire_total}


func apply_placed_save_state(data: Dictionary) -> void:
	last_payout_fire_total = int(data.get("last_payout_fire_total", 0))


func _fires_since_last_payout() -> int:
	return maxi(RunLedger.total_fires - last_payout_fire_total, 0)
