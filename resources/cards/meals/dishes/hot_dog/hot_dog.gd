extends MealCard

## Needs Sausage and a Vegetable. +3 Mult. +1 extra Gold when served while garnished.

const BONUS_GOLD := 1


func _on_activate_tile_card(tile: Hex) -> void:
	var served := is_recipe_ready(tile)
	super._on_activate_tile_card(tile)
	# Garnish is spent by the trigger, so read whether this trigger was garnished.
	if served and _activation_was_garnished:
		_add_quiet_gold(tile, BONUS_GOLD)


func _meal_outputs(_tile: Hex, _preview: bool) -> Dictionary:
	return {"additive_mult": _get_production_amount()}
