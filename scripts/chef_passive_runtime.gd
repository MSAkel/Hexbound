class_name ChefPassiveRuntime
extends RefCounted

# Run-wide chef abilities. Bound from the selected CharacterDefinition.

const SOUS_CHEF_REPEAT_EVERY := 3
const SOMMELIER_BEVERAGE_SCALE := 2.0
const GOURMET_STARTING_GOLD := 10
const GOURMET_DAY_GOLD := 2

var _character: CharacterDefinition = null
# Kitchenware activations this hour, excluding Sous Chef's own bonus repeats.
var _kitchenware_activations_this_hour: int = 0
# True while the extra Sous Chef activation is resolving so it does not count.
var _sous_chef_bonus_active: bool = false


## Bind the chef chosen for this run. Pass null to clear.
func bind(character: CharacterDefinition) -> void:
	_character = character
	reset_turn()


func reset_turn() -> void:
	_kitchenware_activations_this_hour = 0
	_sous_chef_bonus_active = false


func get_kind() -> CharacterDefinition.PassiveKind:
	if _character == null:
		return CharacterDefinition.PassiveKind.NONE
	return _character.passive_kind


func is_sous_chef() -> bool:
	return get_kind() == CharacterDefinition.PassiveKind.SOUS_CHEF


func is_sommelier() -> bool:
	return get_kind() == CharacterDefinition.PassiveKind.SOMMELIER


func is_gourmet() -> bool:
	return get_kind() == CharacterDefinition.PassiveKind.GOURMET_RESTAURANT


## Extra starting gold on top of difficulty. Gourmet only.
func extra_starting_gold() -> int:
	return GOURMET_STARTING_GOLD if is_gourmet() else 0


## Extra gold paid when a day completes. Gourmet only.
func extra_day_completion_gold() -> int:
	return GOURMET_DAY_GOLD if is_gourmet() else 0


## Sommelier doubles Beverage card output. Same path as Double/empower.
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
	if _sous_chef_bonus_active:
		_sous_chef_bonus_active = false
		return

	_kitchenware_activations_this_hour += 1
	if _kitchenware_activations_this_hour % SOUS_CHEF_REPEAT_EVERY != 0:
		return

	_sous_chef_bonus_active = true
	card.queue_tile_card_triggers(tile, [card])
