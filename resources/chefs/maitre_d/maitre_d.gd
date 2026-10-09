extends ChefCard

## Pays gold when the Day goal is met, before the merchant opens.
const DAY_GOLD := 5


func on_day_ended(ctx: ChefContext) -> void:
	ctx.add_gold(DAY_GOLD)
