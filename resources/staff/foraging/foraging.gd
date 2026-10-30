extends StaffCard

## Stocks the belt when a new Day begins. Stops early when the belt is full.
const CONDIMENT_COUNT := 2


func on_day_started(ctx: StaffContext) -> void:
	var drawn := CondimentCatalog.draw_unique(
		CONDIMENT_COUNT, ctx.rng("pantry"), CondimentCatalog.PACK_ID
	)
	var added := 0
	for condiment: Condiment in drawn:
		if not CondimentManager.add_condiment(condiment):
			break
		added += 1
	if added > 0:
		ctx.pulse()
