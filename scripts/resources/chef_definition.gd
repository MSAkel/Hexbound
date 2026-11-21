class_name ChefDefinition
extends Resource

## One playable chef: identity, portraits, starting deck and run-long ability (perk).
## Map geometry is shared by every chef. Add a chef by creating a .tres in resources/chefs/
## and listing it in ChefRegistry.CHEF_PATHS.

## Prefix for a deck entry that draws a random eligible card instead of a fixed one.
## "random:kitchenware", "random:ingredient" or "random:<ingredient tag>" such as "random:fruit".
const RANDOM_PREFIX := "random:"
const RANDOM_INGREDIENT := "ingredient"
## deck_stations choice that means "any Station type not used yet".
const ANY_STATION := "any"

@export var id: String = ""
@export var display_name: String = ""
## Chef selection screen and Collection.
@export var icon: Texture2D = null
## Bottom corner of the run screen, above the gold panel. Falls back to icon.
@export var ingame_portrait: Texture2D = null
@export_multiline var speciality_description: String = ""
## Run-long ability. Null means no ability.
@export var perk: ChefPerk = null
## Starting deck, built from Station kits (resources/station_kits/) in this order.
## Each entry is "<choice>:<size>". choice is a Station type id ("fry_station"), several ids split
## by "|" to roll one of them, or "any" for any Station type not used yet. size is mini, small
## or full (StationKit). The first entry is the home Station.
## Empty deals the default random deck (ChefRegistry.DEFAULT_*_COUNT).
@export var deck_stations: Array[String] = []
## Signature swaps: "<station id>:<kit slot>=<card id>" replaces one kit slot (counted from 1),
## such as "fry_station:6=chicken". They keep the cards that define the chef.
@export var kit_swaps: Array[String] = []


func get_ingame_portrait() -> Texture2D:
	return ingame_portrait if ingame_portrait != null else icon


func has_station_deck() -> bool:
	return not deck_stations.is_empty()
