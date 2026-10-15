class_name LayoutDetails
extends HBoxContainer

# Kept in sync by display_selection so Play can lock in the visible chef.
var _selected_chef: ChefDefinition = null

@onready var chef_name_label: Label = %ChefNameLabel
@onready var chef_icon: TextureRect = %ChefIcon
@onready var speciality_description_label: Label = %SpecialityDescriptionLabel


func display_selection(chef: ChefDefinition) -> void:
	_selected_chef = chef
	chef_name_label.text = chef.display_name.to_upper()
	chef_icon.texture = chef.icon
	speciality_description_label.text = CardKeywordGlossary.to_plain(chef.speciality_description)


func get_selected_chef() -> ChefDefinition:
	return _selected_chef
