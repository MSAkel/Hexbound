class_name DayMealLog
extends RefCounted

## Different Meals served during the current Day, kept in a staff member's run_state so it is
## saved with the slot and rolled back with the playtest bot's what-if Hours.

const DAY_KEY := "log_day"
const MEALS_KEY := "log_meals"


static func record(state: Dictionary, meal: TileCard) -> void:
	if meal == null:
		return
	if int(state.get(DAY_KEY, 0)) != GameManager.current_round:
		state[DAY_KEY] = GameManager.current_round
		state[MEALS_KEY] = []
	var meals: Array = state.get(MEALS_KEY, [])
	if meal.id not in meals:
		meals.append(meal.id)
	state[MEALS_KEY] = meals


static func count(state: Dictionary) -> int:
	if int(state.get(DAY_KEY, 0)) != GameManager.current_round:
		return 0
	var meals: Array = state.get(MEALS_KEY, [])
	return meals.size()


static func clear(state: Dictionary) -> void:
	state.erase(DAY_KEY)
	state.erase(MEALS_KEY)
