extends StaffCard

## Same Hours the Day reward counts as unused.


func on_day_ended(ctx: StaffContext) -> void:
	ctx.add_gold(GameManager.get_skipped_turns())
