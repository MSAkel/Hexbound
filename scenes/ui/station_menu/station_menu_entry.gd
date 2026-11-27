class_name StationMenuEntry
extends PanelContainer

## One Station type listed like a dish: name, a dotted leader to how many of its cards this row
## holds (the "price"), and the requirements underneath.

@export var ingredient_scene: PackedScene

@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _count: Label = %Count
@onready var _complete_count: Label = %CompleteCount
@onready var _ingredients: HBoxContainer = %Ingredients


## cards are the row's regular-spot cards. Call once the node is in the tree.
func setup(station_type: StationType, cards: Array[TileCard]) -> void:
	_icon.texture = station_type.icon
	_name.text = station_type.display_name

	for child: Node in _ingredients.get_children():
		_ingredients.remove_child(child)
		child.queue_free()
	var have := 0
	var needed := 0
	for requirement: StationType.Requirement in station_type.get_requirements(cards):
		have += requirement.have
		needed += requirement.needed
		var ingredient := ingredient_scene.instantiate() as StationMenuIngredient
		_ingredients.add_child(ingredient)
		ingredient.setup(requirement)

	var count_text := "%d/%d" % [have, needed]
	_count.text = count_text
	_complete_count.text = count_text
	_count.visible = have < needed
	_complete_count.visible = have >= needed
