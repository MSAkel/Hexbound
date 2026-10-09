extends ChefCard

## Acts as a second copy of the chef in the next slot down, applied to this slot's course.
## Does nothing in the bottom slot or above an empty one.


func resolve_effect(manager: Node, slot: int, depth: int) -> ChefCard:
	return manager.resolve_effect_at(slot + 1, depth + 1)
