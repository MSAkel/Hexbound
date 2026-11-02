class_name ChefDefinition
extends Resource

## One playable chef: identity, portraits, starting hand and run-long ability (perk).
## Map geometry is shared by every chef. Add a chef by creating a .tres in resources/chefs/
## and listing it in ChefRegistry.CHEF_PATHS.

## Prefix for a starting hand entry that draws a random eligible card instead of a fixed one.
## "random:kitchenware", "random:ingredient" or "random:<ingredient tag>" such as "random:fruit".
const RANDOM_PREFIX := "random:"
const RANDOM_INGREDIENT := "ingredient"

@export var id: String = ""
@export var display_name: String = ""
## Chef selection screen and Collection.
@export var icon: Texture2D = null
## Bottom corner of the run screen, above the gold panel. Falls back to icon.
@export var ingame_portrait: Texture2D = null
@export_multiline var speciality_description: String = ""
## Run-long ability. Null means no ability.
@export var perk: ChefPerk = null
## Opening hand in deal order: card ids ("deep_fryer") or random entries ("random:fruit").
## Empty deals the default random hand (ChefRegistry.STARTING_*_COUNT).
@export var starting_hand: Array[String] = []
## True when the last starting_hand entry is the flex card: the first card a difficulty
## starting-hand reduction removes, so the rest of the hand (a station setup) stays whole.
@export var last_card_is_flex: bool = true


func get_ingame_portrait() -> Texture2D:
	return ingame_portrait if ingame_portrait != null else icon


func has_fixed_starting_hand() -> bool:
	return not starting_hand.is_empty()
