extends Control

# Maximum number of boon slots available to the player
const MAX_SLOTS = 4
const BOON_ITEM = preload("res://scenes/ui/boons_selection/boon_item.tscn")
const BOON = preload("res://scripts/resources/boon.gd")
const MAIN_SCENE = preload("res://scenes/main.tscn")
const MAIN_MENU_SCENE = preload("res://scenes/ui/main_menu/main_menu.tscn")

@onready var boons_container: GridContainer = $Container/Boons/BoonsContainer
@onready var slots_label: Label = $Container/Boons/SlotsLabel

# Array to store the currently selected boons
var selected_boons: Array[BOON] = []
# Track how many slots are currently used
var current_slots_used: int = 0
# Array to keep track of all boon item instances
var boon_items: Array[Node] = []

func _ready() -> void:
	# Load all available boons and create UI items for them
	load_boons()
	# Update the slots label to show initial state
	update_slots_label()

# Load all available boons and create UI items for each one
func load_boons() -> void:
	var boons = BOON.get_all_boons()
	
	for boon in boons:
		# Create a new boon item instance
		var boon_item = BOON_ITEM.instantiate()
		boons_container.add_child(boon_item)
		# Initialize the boon item with its data
		boon_item.setup(boon)
		# Connect to the selection signal
		boon_item.boon_selected.connect(_on_boon_selected)
		# Keep track of the item
		boon_items.append(boon_item)

# Called when a boon is selected or deselected
# Handles slot management and updates the UI
func _on_boon_selected(boon: BOON) -> void:
	# Find the boon item that was selected
	var boon_item = boon_items.filter(func(item): return item.boon == boon)[0]
	
	if boon_item.is_selected:
		# Check if we have enough slots for this boon
		if current_slots_used + boon.cost <= MAX_SLOTS:
			current_slots_used += boon.cost
			selected_boons.append(boon)
		else:
			# Not enough slots, revert the selection
			boon_item.is_selected = false
			boon_item.update_visuals()
	else:
		# Deselecting a boon, free up its slots
		current_slots_used -= boon.cost
		selected_boons.erase(boon)
	
	# Update the UI to show new slot usage
	update_slots_label()

# Update the slots label to show current usage
func update_slots_label() -> void:
	slots_label.text = "Slots used: %d/%d" % [current_slots_used, MAX_SLOTS]

# Called when the start button is pressed
# TODO: Implement game start with selected boons
func _on_start_button_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN_SCENE)

# Return to the main menu
func _on_back_button_pressed() -> void:
	get_tree().change_scene_to_packed(MAIN_MENU_SCENE)
