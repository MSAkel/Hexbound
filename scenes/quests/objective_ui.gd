class_name ObjectiveUI
extends Panel

@onready var icon: TextureRect = $CenterContainer/Icon
@onready var progress_label: Label = $ProgressContainer/ProgressLabel
@onready var objective_ui_border: ObjectiveUI = $"."

var objective: Objective : set = _set_objective

func _ready() -> void:
	Events.quest_progress_updated.connect(_on_quest_progress_updated)

func _set_objective(new_objective: Objective) -> void:
	objective = new_objective
	icon.texture = objective.icon
	progress_label.text = "%d/%d" % [objective.progress, objective.amount_required]
	_change_border_color()

func _on_quest_progress_updated() -> void:
	progress_label.text = "%d/%d" % [objective.progress, objective.amount_required]
	_change_border_color()

func _change_border_color() -> void:
	if objective.completed:
		objective_ui_border.modulate = Color.GREEN
	else:
		objective_ui_border.modulate = Color.WHITE
