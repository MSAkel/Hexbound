extends MealCard

## +3 Mult. Every 5th time it is served, +1 extra Gold.

const SERVES_PER_GOLD := 5
const BONUS_GOLD := 1

var serve_count: int = 0


func _on_activate_tile_card(tile: Hex) -> void:
	super._on_activate_tile_card(tile)
	serve_count += 1
	if serve_count % SERVES_PER_GOLD == 0:
		_add_quiet_gold(tile, BONUS_GOLD)


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}


func capture_placed_save_state() -> Dictionary:
	return {"serve_count": serve_count}


func apply_placed_save_state(data: Dictionary) -> void:
	serve_count = int(data.get("serve_count", 0))
