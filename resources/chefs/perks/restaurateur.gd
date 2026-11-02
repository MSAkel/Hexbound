extends ChefPerk

## Restaurateur: starts with starting_gold instead of the base amount, sees extra tile cards on the
## merchant shelf, and gets free rerolls at the start of each merchant visit.
@export var starting_gold_amount: int = 20
@export var extra_tile_slots: int = 1
@export var free_rerolls: int = 1


func starting_gold(_base_gold: int) -> int:
	return starting_gold_amount


func extra_merchant_tile_slots() -> int:
	return extra_tile_slots


func free_merchant_rerolls() -> int:
	return free_rerolls
