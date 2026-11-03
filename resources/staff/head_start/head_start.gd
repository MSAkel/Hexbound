extends StaffCard

## Read through StationManager.get_segment_thresholds.
const DISCOUNT := 1


func hook_flags() -> int:
	return HOOK_LEVEL_THRESHOLD


func level_threshold_discount(ctx: StaffContext, segment_index: int) -> int:
	return DISCOUNT if segment_index == ctx.slot else 0
