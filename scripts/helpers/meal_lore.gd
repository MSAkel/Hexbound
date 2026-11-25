class_name MealLore
extends RefCounted

## Real-world history for each Meal (who first made it, where, when, the story, fun facts), read
## from resources/meal_lore.json and keyed by Meal card id. The Collection screen shows it, and the
## Meal Collection web page (scripts/debug/catalog/build_meal_collection.py) reads the same file.
## The text is draft lore, separate from game data: a Meal's effect always comes from its card.

const PATH := "res://resources/meal_lore.json"

## Every field an entry is expected to carry. The content check reports entries missing one.
const FIELDS: Array[String] = [
	"origin", "tagline", "first_made_by", "where", "when", "certainty", "certainty_note",
	"story", "facts", "ingredients",
]

static var _meals: Dictionary = {}
static var _loaded := false


## The lore entry for a Meal id, or an empty Dictionary when it has none yet.
static func get_entry(meal_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Variant = _meals.get(meal_id, {})
	return entry as Dictionary if entry is Dictionary else {}


static func has_entry(meal_id: String) -> bool:
	return not get_entry(meal_id).is_empty()


## Every Meal id with a lore entry.
static func get_ids() -> Array[String]:
	_ensure_loaded()
	var ids: Array[String] = []
	for meal_id: Variant in _meals.keys():
		ids.append(String(meal_id))
	return ids


## Fields an entry lacks or leaves empty, for the content check.
static func missing_fields(meal_id: String) -> Array[String]:
	var entry := get_entry(meal_id)
	var missing: Array[String] = []
	for field: String in FIELDS:
		var value: Variant = entry.get(field)
		if value == null or (value is String and (value as String).is_empty()) or (value is Array and (value as Array).is_empty()):
			missing.append(field)
	return missing


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("MealLore: could not open %s." % PATH)
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary and (parsed as Dictionary).get("meals") is Dictionary:
		_meals = (parsed as Dictionary)["meals"]
	else:
		push_error("MealLore: %s has no \"meals\" object." % PATH)
