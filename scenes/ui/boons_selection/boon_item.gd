extends PanelContainer

const BOON = preload("res://scripts/resources/boon.gd")

# References to UI elements in the scene
@onready var name_label: Label = $BoonButton/VBoxContainer/NameLabel
@onready var description_label: Label = $BoonButton/VBoxContainer/DescriptionLabel
@onready var cost_label: Label = $BoonButton/VBoxContainer/CostLabel

# The boon data associated with this item
var boon: BOON
# Whether this boon is currently selected
var is_selected: bool = false

func _ready() -> void:
	# Connect the button press signal to our handler
	$BoonButton.pressed.connect(_on_boon_button_pressed)

# Initialize this boon item with the given boon data
# This is called when the item is created in the boons selection screen
func setup(boon_data: BOON) -> void:
	boon = boon_data
	name_label.text = boon.name
	description_label.text = boon.description
	cost_label.text = "Cost: %d" % boon.cost
	update_visuals()

# Called when the select/deselect button is pressed
# Toggles the selection state and updates the visual appearance
func _on_boon_button_pressed() -> void:
	is_selected = !is_selected
	update_visuals()
	
	# Emit appropriate event based on selection state
	if is_selected:
		Events.boon_selected.emit(boon)
	else:
		Events.boon_deselected.emit(boon)

# Update the visual appearance based on selection state
# Changes button text and adds a green tint when selected
func update_visuals() -> void:
	if is_selected:
		modulate = Color(0.8, 1.0, 0.8)  # Slight green tint
	else:
		modulate = Color.WHITE 
