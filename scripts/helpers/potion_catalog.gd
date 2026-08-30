class_name PotionCatalog
extends RefCounted

## Loads potion resources once and draws unique shop or pack rolls from that pool.

const POTIONS_DIR := "res://resources/potions/"
const PACK_ID := "potion_pack"

static var _pool: Array[Potion] = []
static var _by_id: Dictionary = {}


static func ensure_loaded() -> void:
	if not _pool.is_empty():
		return
	_load_from_directory(POTIONS_DIR)
	_pool.sort_custom(func(a: Potion, b: Potion) -> bool:
		return a.id < b.id
	)


static func get_all() -> Array[Potion]:
	ensure_loaded()
	return _pool


static func get_by_id(potion_id: String) -> Potion:
	ensure_loaded()
	return _by_id.get(potion_id) as Potion


static func draw_unique(count: int, rng: RandomNumberGenerator, exclude_id: String = "") -> Array[Potion]:
	ensure_loaded()
	var bag: Array = []
	for potion in _pool:
		if exclude_id.is_empty() or potion.id != exclude_id:
			bag.append(potion)
	RunRng.shuffle_with(rng, bag)
	var drawn: Array[Potion] = []
	for potion in bag:
		if drawn.size() >= count:
			break
		drawn.append(potion as Potion)
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
		var potion := ResourceLoader.load(resource_path) as Potion
		if potion == null or potion.id.is_empty():
			push_error("PotionCatalog: failed to load %s" % resource_path)
			continue
		if _by_id.has(potion.id):
			continue
		_pool.append(potion)
		_by_id[potion.id] = potion
