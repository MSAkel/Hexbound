class_name StationMenuIngredient
extends PanelContainer

## One requirement in a Station menu entry: icon and text, marked when this row's cards cover it.

@onready var _covered: Panel = %Covered
@onready var _icon: TextureRect = %Icon
@onready var _name: Label = %Name
@onready var _covered_name: Label = %CoveredName
@onready var _partial: Label = %Partial


## Call once the node is in the tree.
func setup(requirement: StationType.Requirement) -> void:
	var covered := requirement.have >= requirement.needed
	_icon.texture = requirement.icon
	_icon.visible = requirement.icon != null
	_name.text = requirement.text
	_covered_name.text = requirement.text
	_covered.visible = covered
	_name.visible = not covered
	_covered_name.visible = covered
	_partial.visible = not covered and requirement.have > 0
	_partial.text = "(%d/%d)" % [requirement.have, requirement.needed]
