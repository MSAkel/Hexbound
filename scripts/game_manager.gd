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

var perks_pool: Array[PerkData] = []
var available_perks: int
var active_perks: Array[PerkData] = []

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

func end_turn() -> void:
	current_year += 1
	available_perks += 1
	for tile in explored_tiles:
		gold_count += 5
		
		if tile._resource_1.id == "berries":
			food_count += tile._resource_1.base_production_rate
		
		if tile.resource_2.id == "berries":
			food_count += tile.resource_2.base_production_rate



func explore_tile(hex: Hex) -> void:
	explored_tiles.append(hex)
	hex.explored = true
	print("Exploring tile at %s" % [hex.coordinates])
	print("Current gold count: %s" % [gold_count])
