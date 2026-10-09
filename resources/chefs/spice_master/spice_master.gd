extends ChefCard

## Mult for each Seasoning fire earlier in the Hour. Retriggers count.
const MULT_PER_SEASONING := 1.0


func on_course_started(ctx: ChefContext) -> void:
	ctx.add_mult(MULT_PER_SEASONING * ChefManager.get_seasoning_fires_this_hour())
