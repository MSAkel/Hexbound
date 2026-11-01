extends MealCard

## +2 Mult, then x1 Mult that gains x0.1 for every earlier trigger this Day. Resets each Day.

const XMULT_PER_TRIGGER := 0.1

var day_trigger_count: int = 0
var trigger_day: int = -1
## Extra xMult from Pub Grub (Fry Station) this Day.
var bonus_xmult_today: float = 0.0


## Pub Grub adds to this Beer's xMult for the rest of the Day.
func add_day_xmult(amount: float) -> void:
	_sync_day()
	bonus_xmult_today += amount


func _on_activate_tile_card(tile: Hex) -> void:
	_sync_day()
	super._on_activate_tile_card(tile)
	day_trigger_count += 1


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	_sync_day()
	return {
		"additive_mult": _get_production_amount(),
		"multiplicative_mult": 1.0 + XMULT_PER_TRIGGER * float(day_trigger_count) + bonus_xmult_today,
	}


func capture_placed_save_state() -> Dictionary:
	_sync_day()
	return {"day_trigger_count": day_trigger_count, "trigger_day": trigger_day, "bonus_xmult_today": bonus_xmult_today}


func apply_placed_save_state(data: Dictionary) -> void:
	day_trigger_count = int(data.get("day_trigger_count", 0))
	trigger_day = int(data.get("trigger_day", GameManager.current_round))
	bonus_xmult_today = float(data.get("bonus_xmult_today", 0.0))
	_sync_day()


func _sync_day() -> void:
	if trigger_day == GameManager.current_round:
		return
	trigger_day = GameManager.current_round
	day_trigger_count = 0
	bonus_xmult_today = 0.0
