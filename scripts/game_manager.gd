extends Node

signal turn_ended()
signal tile_explored(hex: Hex)

var current_year := 1
var gold_count := 0
var food_count := 25

var explored_tiles: Array[Hex] = []

var runes_pool: Array[RuneData] = []
var available_runes: Array[RuneData] = []
var active_runes: Array[RuneData] = []

# Perks variables
var perks_pool: Array[PerkData] = []
var available_perks: int
var active_perks: Array[PerkData] = []
var perks_pack: Array[PerkData] = [] # Perks available for selection on the perks selection menu
var available_perk_rerolls: int = 1

#buildings variables
var buildings_pool: Array[BuildingData] = [] # All buildings available in the game
var buildings_pack: Array[BuildingData] = [] # Buildings available for selection on the buildings selection menu
var selected_building: Array[CardUI] = [] # The building selected by the player
var available_buidling_packs: int = 0 # increment by 1 on turn end
var building_reroll_cost: int = 0 # cost to reroll the building pack, should increment by 5 on each reroll

func _ready() -> void:
	# Load the runes from the resources directory
	var runes_directory = DirAccess.open("res://resources/runes/")
	for file in runes_directory.get_files():
		var rune = load("res://resources/runes/" + file)
		runes_pool.append(rune)
	
	# Load the perks from the resources directory
	var perks_directory = DirAccess.open("res://resources/perks/")
	for file in perks_directory.get_files():
		var rune = load("res://resources/perks/" + file)
		perks_pool.append(rune)

	var buildings_directory = DirAccess.open("res://resources/buildings/")
	for file in buildings_directory.get_files():
		var building = load("res://resources/buildings/" + file)
		buildings_pool.append(building)

	create_buildings_pack()
	create_perks_pack()

func end_turn() -> void:
	current_year += 1
	available_perks += 1
	available_buidling_packs += 1
	for tile in explored_tiles:
		gold_count += 5
		
func explore_tile(hex: Hex) -> void:
	explored_tiles.append(hex)
	hex.explored = true
	print("Exploring tile at %s" % [hex.coordinates])
	print("Current gold count: %s" % [gold_count])

# This function is called when the end turns.
# it will go through the buildings list and randomly select 3 buildings to be available for selection
# Can be staccked on ending turn without selecting a building 
func create_buildings_pack() -> void:
	if buildings_pack.size() == 0:
		var shuffled_pool := buildings_pool.duplicate()
		shuffled_pool.shuffle()

		for i in 3:
			buildings_pack.append(shuffled_pool[i])


func create_perks_pack() -> void:
	if perks_pack.size() == 0:
		var shuffled_pool := perks_pool.duplicate()
		shuffled_pool.shuffle()

		for i in 3:
			perks_pack.append(shuffled_pool[i])
