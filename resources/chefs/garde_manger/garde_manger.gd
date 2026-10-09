extends ChefCard

## Every Dish on the pass may leave one ingredient slot of its recipe empty.
const WAIVED_INGREDIENTS := 1


func dish_ingredient_discount(_ctx: ChefContext) -> int:
	return WAIVED_INGREDIENTS
