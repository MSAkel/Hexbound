extends StaffCard

## Read through StationManager.get_effective_level. Capped at the max level.
const EXTRA_LEVELS := 1


func hook_flags() -> int:
	return HOOK_STATION_LEVEL


func station_level_bonus(ctx: StaffContext, segment_index: int) -> int:
	return EXTRA_LEVELS if segment_index == ctx.slot else 0
