class_name LayoutDetails
extends HBoxContainer

# Kept in sync by display_selection so Play can lock in the visible chef.
var _selected_character: CharacterDefinition = null

@onready var character_name_label: Label = %CharacterNameLabel
@onready var character_icon: TextureRect = %CharacterIcon
@onready var passive_title_label: Label = %PassiveTitleLabel
@onready var passive_description_label: Label = %PassiveDescriptionLabel
@onready var layout_xp_bar: LayoutXpBar = %LayoutXpBar


func display_selection(character: CharacterDefinition) -> void:
	_selected_character = character
	character_name_label.text = character.display_name.to_upper()
	character_icon.texture = character.icon
	passive_title_label.text = "PASSIVE"
	passive_description_label.text = character.passive_description
	_refresh_xp_display(character.id)


func _refresh_xp_display(character_id: String) -> void:
	MetaProgressionManager.ensure_loaded()
	var xp := MetaProgressionManager.get_layout_xp(character_id)
	layout_xp_bar.show_xp_total(xp)


func get_selected_character() -> CharacterDefinition:
	return _selected_character
