extends StaffCard

## Leftovers (user, Nov 24; the name is a placeholder): at the end of the Day, 1 Gold for each hand
## discard left unused. Pays up to DeckManager.HAND_DISCARDS_PER_DAY a Day, and more the less the
## player digs, so it is priced low (price_override 2, a Common is 4). Untuned.

const GOLD_PER_DISCARD := 1


func on_day_ended(ctx: StaffContext) -> void:
	ctx.add_gold(GOLD_PER_DISCARD * DeckManager.discards_left)
