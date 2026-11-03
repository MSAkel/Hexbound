extends StaffCard

## Read through StationManager.get_segment_thresholds.
const DISCOUNT := 1


func level_threshold_discount(ctx: StaffContext, segment_index: int) -> int:
	return DISCOUNT if segment_index == ctx.slot else 0
