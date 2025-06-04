extends Node

signal tile_explored(hex: Hex)
signal game_speed_changed(new_speed: float)


var explores_per_turn := 1

var _current_year := 1

var _gold_count := 0
var _favor_count := 0
var _insight_count := 0

var _available_explores: int = 0
var _game_speed: float = 1.0
var _is_processing_turn: bool = false  # Block input processing while turn is being processed

var explored_tiles: Array[Hex] = []

var buildings_pool: Array[Building] = [] # All buildings available in the game
var buildings_pack: Array[Building] = [] # Buildings available for selection on the buildings selection menu
var _available_building_packs: int = 1 # increment by 1 on turn end
var _building_reroll_cost: int = 0 # cost to reroll the building pack, should increment by 5 on each reroll

var runes_pool: Array[Rune] = []
var runes_pack: Array[Rune] = []
var _available_runes_packs: int = 1
var _runes_reroll_cost: int = 0
var active_runes: Array[Rune] = []

var perks_pool: Array[Perk] = []
var _available_perks: int
var active_perks: Array[Perk] = []
var perks_pack: Array[Perk] = [] # Perks available for selection on the perks selection menu
var _available_perk_rerolls: int = 1


var selected_boons: Array[Boon] = []

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
		Events.gold_changed.emit(_gold_count)
		# look for potential perks/runes which could impact gold production or adding signals here if needed

var favor_count: int:
	get:
		return _favor_count
	set(value):
		_favor_count = max(0, value) 

var insight_count: int:
	get:
		return _insight_count
	set(value):
		_insight_count = max(0, value)

var available_explores: int:
	get:
		return _available_explores
	set(value):
		_available_explores = clamp(value, 0, 50)
		Events.explore_count_changed.emit()


var game_speed: float:
	get:
		return _game_speed
	set(value):
		_game_speed = clamp(value, 1, 3.0)  # Limit speed between 1x and 3x
		game_speed_changed.emit(_game_speed)

# Buildings
var available_building_packs: int:
	get:
		return _available_building_packs
	set(value):
		_available_building_packs = max(0, value)
		Events.building_pack_count_changed.emit()

var building_reroll_cost: int:
	get:
		return _building_reroll_cost
	set(value):
		_building_reroll_cost = max(0, value)


# Runes
var available_runes_packs: int:
	get:
		return _available_runes_packs
	set(value):
		_available_runes_packs = max(0, value)


var runes_reroll_cost: int:
	get:
		return _runes_reroll_cost
	set(value):
		_runes_reroll_cost = max(0, value)

# Perks
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


# Add a getter for the processing state
var is_processing_turn: bool:
	get:
		return _is_processing_turn

func _ready() -> void:
	# Initialize available explores
	_available_explores = explores_per_turn
	
	# Load the runes from the resources directory
	var runes_directory = DirAccess.open("res://resources/runes/")
	for file in runes_directory.get_files():
		if file.ends_with(".tres"):
			var rune = load("res://resources/runes/" + file)
			runes_pool.append(rune)
	
	# Load the perks from the resources directory
	var perks_directory = DirAccess.open("res://resources/perks/")
	for file in perks_directory.get_files():
		if file.ends_with(".tres"):
			var perk = load("res://resources/perks/" + file)
			perks_pool.append(perk)

	var buildings_directory = DirAccess.open("res://resources/buildings/")
	for file in buildings_directory.get_files():
		if file.ends_with(".tres"):
			var building = load("res://resources/buildings/" + file)
			buildings_pool.append(building)

	create_buildings_pack()
	create_runes_pack()
	create_perks_pack()

	Events.turn_ended.connect(end_turn)

func end_turn() -> void:
	_is_processing_turn = true

func finish_turn_processing() -> void:
	_is_processing_turn = false
	_current_year += 1
	available_perks += 1
	available_building_packs += 1
	available_runes_packs += 1
	_available_explores = explores_per_turn
	Events.turn_started.emit()

func update_explored_tiles_list(h: Hex) -> void:
	explored_tiles.append(h)
	explored_tiles.sort_custom(func(a, b):
		var ca = a._coordinates
		var cb = b._coordinates
		# First sort by y (row), then by x (column)
		if ca.y != cb.y:
			return ca.y < cb.y
		return ca.x < cb.x
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

func create_runes_pack() -> void:
	if runes_pack.size() == 0:
		var shuffled_pool := runes_pool.duplicate()
		shuffled_pool.shuffle()

		for i in 3:
			runes_pack.append(shuffled_pool[i])

func create_perks_pack() -> void:
	if perks_pack.size() == 0:
		var shuffled_pool := perks_pool.duplicate()
		shuffled_pool.shuffle()

		for i in 3:
			perks_pack.append(shuffled_pool[i])

func set_game_speed(speed: float) -> void:
	_game_speed = speed
	game_speed_changed.emit(_game_speed)
