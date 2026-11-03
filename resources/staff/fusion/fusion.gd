extends StaffCard

## Rewards a mixed board rather than a mixed row (Blender and Fry already do that).
const FLAVOUR_PER_TYPE := 15


func on_station_started(ctx: StaffContext) -> void:
	var types: Dictionary = {}
	for segment in StaffManager.SLOT_COUNT:
		var type_id := StationManager.get_station_type_id(segment)
		if not type_id.is_empty():
			types[type_id] = true
	ctx.add_flavour(FLAVOUR_PER_TYPE * types.size())
