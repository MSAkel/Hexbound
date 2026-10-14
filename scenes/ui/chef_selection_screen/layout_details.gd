class_name LayoutDetails
extends HBoxContainer

# Kept in sync by display_selection so Play can lock in the visible chef.
var _selected_chef: ChefDefinition = null

@onready var chef_name_label: Label = %ChefNameLabel
@onready var chef_icon: TextureRect = %ChefIcon
@onready var speciality_description_label: Label = %SpecialityDescriptionLabel
@onready var layout_xp_bar: LayoutXpBar = %LayoutXpBar


func display_selection(chef: ChefDefinition) -> void:
	_selected_chef = chef
	chef_name_label.text = chef.display_name.to_upper()
	chef_icon.texture = chef.icon
	speciality_description_label.text = CardKeywordGlossary.to_plain(chef.speciality_description)
	_refresh_xp_display(chef.id)


func _refresh_xp_display(chef_id: String) -> void:
	MetaProgressionManager.ensure_loaded()
	var xp := MetaProgressionManager.get_layout_xp(chef_id)
	layout_xp_bar.show_xp_total(xp)


func get_selected_chef() -> ChefDefinition:
	return _selected_chef
