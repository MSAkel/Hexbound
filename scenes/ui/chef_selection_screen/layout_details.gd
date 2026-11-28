class_name LayoutDetails
extends HBoxContainer

## Multiplies a locked chef's portrait to a flat black shape. Alpha stays.
@export var locked_silhouette_color := Color(0, 0, 0, 1)

# Kept in sync by display_selection so Play can lock in the visible chef.
var _selected_chef: ChefDefinition = null

@onready var chef_name_label: Label = %ChefNameLabel
@onready var chef_icon: TextureRect = %ChefIcon
@onready var speciality_description_label: Label = %SpecialityDescriptionLabel
@onready var progress_label: Label = %ProgressLabel
@onready var progress_count: Label = %ProgressCount
@onready var progress_bar: ProgressBar = %ProgressBar
@onready var progress_gap: Control = %ProgressGap
@onready var progress_row: HBoxContainer = %ProgressRow


## A locked chef (ChefProgression.is_chef_unlocked) shows LOCKED, its unlock condition and a
## silhouette, and no chef level: it can't earn XP yet.


func display_selection(chef: ChefDefinition) -> void:
	_selected_chef = chef
	var unlocked := ChefProgression.is_chef_unlocked(chef.id)
	chef_icon.texture = chef.icon
	chef_icon.self_modulate = Color.WHITE if unlocked else locked_silhouette_color
	for node: Control in [progress_gap, progress_row, progress_bar]:
		node.visible = unlocked
	if not unlocked:
		chef_name_label.text = "LOCKED"
		speciality_description_label.text = ChefProgression.get_unlock_condition_text(chef.id)
		return
	chef_name_label.text = chef.display_name.to_upper()
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
