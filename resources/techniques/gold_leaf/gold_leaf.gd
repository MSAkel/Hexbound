extends StaffCard

## Pays Flavour for banked gold, so it rewards saving over spending.
const FLAVOUR_PER_GOLD := 3


func on_station_started(ctx: StaffContext) -> void:
	ctx.add_flavour(FLAVOUR_PER_GOLD * maxi(0, EconomyManager.amount))
