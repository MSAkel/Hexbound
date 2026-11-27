class_name LayoutDetails
extends HBoxContainer

# Kept in sync by display_selection so Play can lock in the visible chef.
var _selected_chef: ChefDefinition = null

@onready var chef_name_label: Label = %ChefNameLabel
@onready var chef_icon: TextureRect = %ChefIcon
@onready var speciality_description_label: Label = %SpecialityDescriptionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_count: Label = %ProgressCount
@onready var progress_bar: ProgressBar = %ProgressBar


func display_selection(chef: ChefDefinition) -> void:
	_selected_chef = chef
	chef_name_label.text = chef.display_name.to_upper()
	chef_icon.texture = chef.icon
	speciality_description_label.text = CardKeywordGlossary.to_plain(chef.speciality_description)
	_display_chef_level(int(CollectionStats.get_chef_stats(chef.id)["xp"]))


func get_selected_chef() -> ChefDefinition:
	return _selected_chef


## Chef level and EXP towards the next level (ChefProgression), or "Max level".
func _display_chef_level(xp: int) -> void:
	var level := ChefProgression.level_for_xp(xp)
	progress_label.text = "CHEF LEVEL %d" % level
	if level >= ChefProgression.MAX_LEVEL:
		progress_bar.min_value = 0
		progress_bar.max_value = 1
		progress_bar.value = 1
		progress_count.text = "MAX LEVEL"
		return
	var next_xp := ChefProgression.xp_for_level(level + 1)
	progress_bar.min_value = ChefProgression.xp_for_level(level)
	progress_bar.max_value = next_xp
	progress_bar.value = xp
	progress_count.text = "%s / %s EXP" % [CountingNumber.format_int(xp), CountingNumber.format_int(next_xp)]
