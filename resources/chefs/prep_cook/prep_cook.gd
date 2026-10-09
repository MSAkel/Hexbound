extends ChefCard

## Mult for each Ingredient seated on this course.
const MULT_PER_INGREDIENT := 2.0


func on_course_started(ctx: ChefContext) -> void:
	var ingredients := ctx.course_cards(TileCard.TileCardType.INGREDIENT)
	ctx.add_mult(MULT_PER_INGREDIENT * ingredients.size())
