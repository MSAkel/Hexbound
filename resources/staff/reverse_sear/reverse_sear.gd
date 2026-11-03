extends StaffCard

## HexBoardQuery rebuilds the trigger order whenever the roster changes.


func hook_flags() -> int:
	return HOOK_REVERSE_STATION


func reverses_station(_ctx: StaffContext) -> bool:
	return true
