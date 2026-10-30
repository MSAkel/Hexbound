extends StaffCard

## Grows for the rest of the run on every repeat fire on this station. Pays out when the station starts.
## A card's second and later fires in one Hour count as retriggers.
const FLAVOUR_PER_RETRIGGER := 5.0


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_flavour(int(run_total("flavour")))


func on_card_activated(ctx: StaffContext, tile: Hex, card: TileCard) -> void:
	if not ctx.is_on_station(tile):
		return
	var fires: Dictionary = ctx.hour_state.get_or_add("fires", {})
	var previous := int(fires.get(card, 0))
	fires[card] = previous + 1
	if previous > 0:
		ctx.grow("flavour", FLAVOUR_PER_RETRIGGER, tile)


func get_progress_text() -> String:
	return "%s {flavour}" % format_total(run_total("flavour"))
