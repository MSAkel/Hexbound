class_name LayoutDetails
extends HBoxContainer

# Kept in sync by display_selection so Play can lock in the visible specialty.
var _selected_specialty: SpecialtyDefinition = null

@onready var specialty_name_label: Label = %SpecialtyNameLabel
@onready var specialty_icon: TextureRect = %SpecialtyIcon
@onready var passive_title_label: Label = %PassiveTitleLabel
@onready var passive_description_label: Label = %PassiveDescriptionLabel
@onready var layout_xp_bar: LayoutXpBar = %LayoutXpBar


func display_selection(specialty: SpecialtyDefinition) -> void:
	_selected_specialty = specialty
	specialty_name_label.text = specialty.display_name.to_upper()
	specialty_icon.texture = specialty.icon
	passive_title_label.text = "PASSIVE"
	passive_description_label.text = CardKeywordGlossary.to_plain(specialty.passive_description)
	_refresh_xp_display(specialty.id)


func _refresh_xp_display(specialty_id: String) -> void:
	MetaProgressionManager.ensure_loaded()
	var xp := MetaProgressionManager.get_layout_xp(specialty_id)
	layout_xp_bar.show_xp_total(xp)


func get_selected_specialty() -> SpecialtyDefinition:
	return _selected_specialty
