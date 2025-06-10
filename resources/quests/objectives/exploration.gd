extends Objective

func _init() -> void:
	GameManager.tile_explored.connect(_update_progress.unbind(1))
	# Defer the update_progress call to the next frame to ensure UI is ready
	call_deferred("_update_progress")

func _update_progress() -> void:
	progress = GameManager.explored_tiles.size()
	completed = progress >= amount_required
	Events.quest_progress_updated.emit()
