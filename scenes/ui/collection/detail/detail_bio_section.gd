class_name CollectionDetailBioSection
extends VBoxContainer

## Chef page: bio parts top to bottom. Unlocked parts show their text; only the next locked part
## shows, as a lock row with its chef level. Locked text is never shown, and a part with no text
## written yet stays locked.

const PART_SCENE := preload("res://scenes/ui/collection/detail/bio_part.tscn")
const LOCKED_ROW_SCENE := preload("res://scenes/ui/collection/detail/bio_locked_row.tscn")

@onready var _parts: VBoxContainer = %Parts


## parts: [{"part", "level", "text"}] from ChefProgression, in order.
func setup(parts: Array[Dictionary], chef_level: int) -> void:
	if not is_node_ready():
		await ready
	for part: Dictionary in parts:
		var label := "Part %d" % int(part.get("part", 0))
		var required := int(part.get("level", 0))
		var text := String(part.get("text", ""))
		if chef_level < required or text.is_empty():
			var locked := LOCKED_ROW_SCENE.instantiate() as CollectionBioLockedRow
			_parts.add_child(locked)
			locked.setup(label, required)
			return
		var unlocked := PART_SCENE.instantiate() as CollectionBioPart
		_parts.add_child(unlocked)
		unlocked.setup(label, text.replace("[", "[lb]"))
