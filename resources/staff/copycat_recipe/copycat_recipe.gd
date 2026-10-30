extends StaffCard

## Acts as a second copy of the staff member in the next slot down, applied to this slot's station.
## Does nothing in the bottom slot or above an empty one.


func resolve_effect(manager: Node, slot: int, depth: int) -> StaffCard:
	return manager.resolve_effect_at(slot + 1, depth + 1)
