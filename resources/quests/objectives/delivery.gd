class_name Delivery
extends Objective

@export var good_type: GoodType.Type

func _init() -> void:
	GoodsManager.good_amount_changed.connect(_update_progress.unbind(1))
	# Defer the update_progress call to the next frame to ensure UI is ready
	call_deferred("_update_progress")

func _update_progress() -> void:
	progress = GoodsManager.get_good_amount(good_type)
	completed = progress >= amount_required
	Events.quest_progress_updated.emit()

	if completed:
		GoodsManager.good_amount_changed.disconnect(_update_progress)


func cleanup() -> void:
	GoodsManager.remove_good(good_type, amount_required)
