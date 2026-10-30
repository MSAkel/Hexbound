extends StaffCard

## Interest on banked gold, paid when the Day goal is met.
const GOLD_STEP := 5
const MAX_GOLD := 5


func on_day_ended(ctx: StaffContext) -> void:
	ctx.add_gold(mini(floori(EconomyManager.amount / float(GOLD_STEP)), MAX_GOLD))
