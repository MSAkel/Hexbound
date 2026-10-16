class_name ChefSpecialityRuntime
extends RefCounted

# Run-wide chef abilities. Bound from the selected ChefDefinition.

const SOUS_CHEF_REPEAT_EVERY := 3
const SOMMELIER_BEVERAGE_SCALE := 2.0
const GOURMET_STARTING_GOLD := 20
const GOURMET_MEAL_GOLD := 1

var _chef: ChefDefinition = null
# Kitchenware activations this hour, excluding Sous Chef's own bonus repeats.
var _kitchenware_activations_this_hour: int = 0
# True while the extra Sous Chef activation is resolving so it does not count.
var _sous_chef_bonus_active: bool = false


## Bind the chef chosen for this run. Pass null to clear.
func bind(chef: ChefDefinition) -> void:
	_chef = chef
	reset_turn()


func reset_turn() -> void:
	_kitchenware_activations_this_hour = 0
	_sous_chef_bonus_active = false


func get_kind() -> ChefDefinition.SpecialityKind:
	if _chef == null:
		return ChefDefinition.SpecialityKind.NONE
	return _chef.speciality_kind


func is_sous_chef() -> bool:
	return get_kind() == ChefDefinition.SpecialityKind.SOUS_CHEF


func is_sommelier() -> bool:
	return get_kind() == ChefDefinition.SpecialityKind.SOMMELIER


func is_gourmet() -> bool:
	return get_kind() == ChefDefinition.SpecialityKind.GOURMET_RESTAURANT


## Starting gold before the difficulty reduction. Gourmet replaces the base amount.
func starting_gold() -> int:
	return GOURMET_STARTING_GOLD if is_gourmet() else Difficulty.BASE_STARTING_GOLD


## Extra gold paid each time a Meal is served. Gourmet only.
func extra_meal_gold() -> int:
	return GOURMET_MEAL_GOLD if is_gourmet() else 0


## Sommelier doubles Beverage card output. Same output scale path as Garnish.
func beverage_output_scale(card: TileCard) -> float:
	if not is_sommelier() or card == null:
		return 1.0
	if not card.has_ingredient_tag(TileCard.TAG_BEVERAGE):
		return 1.0
	return SOMMELIER_BEVERAGE_SCALE


## After a Kitchenware resolves, maybe queue one extra activation of the same card.
func maybe_repeat_kitchenware(tile: Hex, card: TileCard) -> void:
	if not is_sous_chef() or tile == null or card == null:
		return
	if card.type != TileCard.TileCardType.KITCHENWARE:
		return
	# Cards that cannot be retriggered (Fire Extinguisher, Chef's Knife) do not count toward the repeat.
	if not card.can_be_triggered_by_other_card(tile):
		return
	if _sous_chef_bonus_active:
		_sous_chef_bonus_active = false
		return

	_kitchenware_activations_this_hour += 1
	if _kitchenware_activations_this_hour % SOUS_CHEF_REPEAT_EVERY != 0:
		return

	_sous_chef_bonus_active = true
	card.queue_tile_card_triggers(tile, [card])
