class_name StaffCatalog
extends RefCounted

# Preload so StaffCard resolves when this script is parsed before global class scan.
const _StaffCardScript := preload("res://scripts/resources/staff_card.gd")

## Loads staff resources once and drafts merchant offers from that pool.

const STAFF_DIR := "res://resources/staff/"

static var _pool: Array[StaffCard] = []
static var _by_id: Dictionary = {}


static func ensure_loaded() -> void:
	if not _pool.is_empty():
		return
	_load_from_directory(STAFF_DIR)
	_pool.sort_custom(func(a: StaffCard, b: StaffCard) -> bool:
		return a.id < b.id
	)


static func get_all() -> Array[StaffCard]:
	ensure_loaded()
	return _pool


static func get_by_id(staff_id: String) -> StaffCard:
	ensure_loaded()
	return _by_id.get(staff_id) as StaffCard


## Rarity-weighted draft with no repeats. exclude_ids keeps owned staff off the shelf.
static func draw(
	count: int,
	rng: RandomNumberGenerator,
	exclude_ids: Array[String] = []
) -> Array[StaffCard]:
	ensure_loaded()
	var available: Array[StaffCard] = []
	for staff: StaffCard in _pool:
		if staff.id not in exclude_ids:
			available.append(staff)

	var drawn: Array[StaffCard] = []
	for _i in count:
		if available.is_empty():
			break
		var rarity := CardLoot.roll_rarity(CardLoot.RARITY_WEIGHTS, rng)
		var candidates: Array[StaffCard] = []
		for staff: StaffCard in available:
			if staff.rarity == rarity:
				candidates.append(staff)
		# Fall back to any remaining staff when the rolled rarity is sold out.
		var bucket := candidates if not candidates.is_empty() else available
		var picked: StaffCard = bucket[rng.randi_range(0, bucket.size() - 1)]
		available.erase(picked)
		drawn.append(picked.duplicate(true))
	return drawn


static func _load_from_directory(dir_path: String) -> void:
	var normalized := dir_path
	if not normalized.ends_with("/"):
		normalized += "/"

	for entry in ResourceLoader.list_directory(normalized):
		if entry == "./" or entry == "../":
			continue
		if entry.ends_with("/"):
			_load_from_directory(normalized.path_join(entry.trim_suffix("/")))
			continue
		if not entry.ends_with(".tres"):
			continue
		var resource_path := normalized.path_join(entry)
		var staff := ResourceLoader.load(resource_path) as StaffCard
		if staff == null or staff.id.is_empty():
			push_error("StaffCatalog: failed to load %s" % resource_path)
			continue
		if _by_id.has(staff.id):
			continue
		_pool.append(staff)
		_by_id[staff.id] = staff
