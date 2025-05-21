extends Node

signal turn_ended()
signal tile_explored(hex: Hex)
signal game_speed_changed(new_speed: float)

# Game constants
const BASE_EXPLORES_PER_TURN := 1
const MAX_EXPLORES := 3

var _current_year := 1
var _gold_count := 0
var _food_count := 25
var _available_explores: int = 0
var _game_speed: float = 1.0  # 1.0 is normal speed, 2.0 is double, 3.0 is triple

var explored_tiles: Array[Hex] = []

var runes_pool: Array[Rune] = []
var active_runes: Array[Rune] = []

var perks_pool: Array[Perk] = []
var _available_perks: int
var active_perks: Array[Perk] = []
var perks_pack: Array[Perk] = [] # Perks available for selection on the perks selection menu
var _available_perk_rerolls: int = 1

var buildings_pool: Array[BuildingData] = [] # All buildings available in the game
var buildings_pack: Array[BuildingData] = [] # Buildings available for selection on the buildings selection menu
var selected_building: Array[CardUI] = [] # The building selected by the player
var _available_building_packs: int = 0 # increment by 1 on turn end
var _building_reroll_cost: int = 0 # cost to reroll the building pack, should increment by 5 on each reroll

var selected_boons: Array[Boon] = []

# Essence, each tile gives 1 essence of a specific type
var _nature_essence: int = 0
var _fire_essence: int = 0
var _frost_essence: int = 0
var _storm_essence: int = 0

# Core game state getters and setters
var current_year: int:
	get:
		return _current_year
	set(value):
		_current_year = max(1, value)

var gold_count: int:
	get:
		return _gold_count
	set(value):
		_gold_count = max(0, value)
		# look for potential perks/runes which could impact gold production or adding signals here if needed

var food_count: int:
	get:
		return _food_count
	set(value):
		_food_count = max(0, value) 

var available_explores: int:
	get:
		return _available_explores
	set(value):
		_available_explores = clamp(value, 0, MAX_EXPLORES)

var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = clamp(value, 1, 3.0)  # Limit speed between 1x and 3x
		game_speed_changed.emit(_game_speed)

# Perk and building related getters and setters
var available_perks: int:
	get:
		return _available_perks
	set(value):
		_available_perks = max(0, value)

var available_perk_rerolls: int:
	get:
		return _available_perk_rerolls
	set(value):
		_available_perk_rerolls = max(0, value)

var available_building_packs: int:
	get:
		return _available_building_packs
	set(value):
		_available_building_packs = max(0, value)

var building_reroll_cost: int:
	get:
		return _building_reroll_cost
	set(value):
		_building_reroll_cost = max(0, value)

# Essence getters and setters
var nature_essence: int:
	get:
		return _nature_essence
	set(value):
		_nature_essence = max(0, value)

var fire_essence: int:
	get:
		return _fire_essence
	set(value):
		_fire_essence = max(0, value)

var frost_essence: int:
	get:
		return _frost_essence
	set(value):
		_frost_essence = max(0, value)

var storm_essence: int:
	get:
		return _storm_essence
	set(value):
		_storm_essence = max(0, value)

func _ready() -> void:
	# Initialize available explores
	_available_explores = BASE_EXPLORES_PER_TURN
	
	# Load the runes from the resources directory
	var runes_directory = DirAccess.open("res://resources/runes/")
	for file in runes_directory.get_files():
		var rune = load("res://resources/runes/" + file)
		runes_pool.append(rune)
	
	# Load the perks from the resources directory
	var perks_directory = DirAccess.open("res://resources/perks/")
	for file in perks_directory.get_files():
		var perk = load("res://resources/perks/" + file)
		perks_pool.append(perk)

	var buildings_directory = DirAccess.open("res://resources/buildings/")
	for file in buildings_directory.get_files():
		var building = load("res://resources/buildings/" + file)
		buildings_pool.append(building)

	create_buildings_pack()
	create_perks_pack()

	turn_ended.connect(end_turn)

func end_turn() -> void:
	_current_year += 1
	available_perks += 1
	available_building_packs += 1
	_available_explores = BASE_EXPLORES_PER_TURN

func update_explored_tiles_list(h: Hex) -> void:
	explored_tiles.append(h)
	explored_tiles.sort_custom(func(a, b):
		var ca = a._coordinates
		var cb = b._coordinates
		return ca.y == cb.y if ca.x < cb.x else ca.y < cb.y
	)


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

func set_game_speed(speed: float) -> void:
	_game_speed = speed
	game_speed_changed.emit(_game_speed)
