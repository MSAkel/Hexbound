extends StaffCard

## Borrows only level 3 picks. This station needs a type of its own.


func borrowed_station_perks(ctx: StaffContext, segment_index: int) -> Array[StationPerk]:
	var perks: Array[StationPerk] = []
	if segment_index != ctx.slot or StationManager.get_station_type(segment_index) == null:
		return perks
	for side: int in StationManager.adjacent_segments(segment_index):
		var side_type := StationManager.get_station_type(side)
		if side_type == null:
			continue
		for perk: StationPerk in StationManager.get_picked_perks(side):
			if perk in side_type.choice_options:
				perks.append(perk)
	return perks
