class_name SegmentPassiveUnlockPresenter
extends RefCounted

const REVEAL_SCENE := preload("res://scenes/ui/segment_passives/segment_passive_unlock_reveal.tscn")


static func present_if_needed(host: Node) -> void:
	if host == null or not MetaProgressionManager.has_pending_unlock_reveals():
		return
	var reveal := REVEAL_SCENE.instantiate()
	host.add_child(reveal)
