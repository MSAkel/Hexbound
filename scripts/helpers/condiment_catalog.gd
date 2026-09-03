class_name CondimentCatalog
extends RefCounted

# Preload so Condiment resolves when this script is parsed before global class scan.
const _CondimentScript := preload("res://scripts/resources/condiment.gd")

## Loads condiment resources once and draws unique shop or pack rolls from that pool.

const CONDIMENTS_DIR := "res://resources/condiments/"
const PACK_ID := "condiment_pack"

static var _pool: Array[Condiment] = []
static var _by_id: Dictionary = {}


static func ensure_loaded() -> void:
	if not _pool.is_empty():
		return
	_load_from_directory(CONDIMENTS_DIR)
	_pool.sort_custom(func(a: Condiment, b: Condiment) -> bool:
		return a.id < b.id
	)


static func get_all() -> Array[Condiment]:
	ensure_loaded()
	return _pool


static func get_by_id(condiment_id: String) -> Condiment:
	ensure_loaded()
	return _by_id.get(condiment_id) as Condiment


static func draw_unique(count: int, rng: RandomNumberGenerator, exclude_id: String = "") -> Array[Condiment]:
	ensure_loaded()
	var bag: Array = []
	for condiment in _pool:
		if exclude_id.is_empty() or condiment.id != exclude_id:
			bag.append(condiment)
	RunRng.shuffle_with(rng, bag)
	var drawn: Array[Condiment] = []
	for condiment in bag:
		if drawn.size() >= count:
			break
		drawn.append(condiment as Condiment)
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
		var condiment := ResourceLoader.load(resource_path) as Condiment
		if condiment == null or condiment.id.is_empty():
			push_error("CondimentCatalog: failed to load %s" % resource_path)
			continue
		if _by_id.has(condiment.id):
			continue
		_pool.append(condiment)
		_by_id[condiment.id] = condiment
