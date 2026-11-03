extends StaffCard

## Works from any seat. Named recipe cards come first, then cards of a kind a recipe asks for.


func wants_recipe_card_in_picks(_ctx: StaffContext) -> bool:
	return true
