extends ChefPerk

## Restaurateur: starts with starting_gold instead of the base amount and gets free rerolls at the
## start of each merchant visit.
@export var starting_gold_amount: int = 20
@export var free_rerolls: int = 1


func starting_gold(_base_gold: int) -> int:
	return starting_gold_amount


func free_merchant_rerolls() -> int:
	return free_rerolls
