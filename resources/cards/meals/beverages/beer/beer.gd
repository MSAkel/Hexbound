extends MealCard

## +1 Mult, plus +0.5 Mult for every earlier trigger this Day. Resets each Day. Gives no xMult
## (Meals no longer do). Untuned.

const MULT_PER_TRIGGER := 0.5

var day_trigger_count: int = 0
var trigger_day: int = -1
## Extra +Mult from Pub Grub (Fry Station) this Day.
var bonus_mult_today: float = 0.0


## Pub Grub adds to this Beer's +Mult for the rest of the Day.
func add_day_mult(amount: float) -> void:
	_sync_day()
	bonus_mult_today += amount


func _on_activate_tile_card(tile: Hex) -> void:
	_sync_day()
	super._on_activate_tile_card(tile)
	day_trigger_count += 1


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	_sync_day()
	return {
		"additive_mult": _get_production_amount() + MULT_PER_TRIGGER * float(day_trigger_count) + bonus_mult_today,
	}


func capture_placed_save_state() -> Dictionary:
	_sync_day()
	return {"day_trigger_count": day_trigger_count, "trigger_day": trigger_day, "bonus_mult_today": bonus_mult_today}


func apply_placed_save_state(data: Dictionary) -> void:
	day_trigger_count = int(data.get("day_trigger_count", 0))
	trigger_day = int(data.get("trigger_day", GameManager.current_round))
	bonus_mult_today = float(data.get("bonus_mult_today", 0.0))
	_sync_day()


func _sync_day() -> void:
	if trigger_day == GameManager.current_round:
		return
	trigger_day = GameManager.current_round
	day_trigger_count = 0
	bonus_mult_today = 0.0
