class_name ChefCatalog
extends RefCounted

# Preload so ChefCard resolves when this script is parsed before global class scan.
const _ChefCardScript := preload("res://scripts/resources/chef_card.gd")

## Loads chef resources once and drafts merchant offers from that pool.

const CHEFS_DIR := "res://resources/chefs/"

static var _pool: Array[ChefCard] = []
static var _by_id: Dictionary = {}


static func ensure_loaded() -> void:
	if not _pool.is_empty():
		return
	_load_from_directory(CHEFS_DIR)
	_pool.sort_custom(func(a: ChefCard, b: ChefCard) -> bool:
		return a.id < b.id
	)


static func get_all() -> Array[ChefCard]:
	ensure_loaded()
	return _pool


static func get_by_id(chef_id: String) -> ChefCard:
	ensure_loaded()
	return _by_id.get(chef_id) as ChefCard


## Rarity-weighted draft with no repeats. exclude_ids keeps owned chefs off the shelf.
static func draw(
	count: int,
	rng: RandomNumberGenerator,
	exclude_ids: Array[String] = []
) -> Array[ChefCard]:
	ensure_loaded()
	var available: Array[ChefCard] = []
	for chef: ChefCard in _pool:
		if chef.id not in exclude_ids:
			available.append(chef)

	var drawn: Array[ChefCard] = []
	for _i in count:
		if available.is_empty():
			break
		var rarity := CardLoot.roll_rarity(CardLoot.RARITY_WEIGHTS, rng)
		var candidates: Array[ChefCard] = []
		for chef: ChefCard in available:
			if chef.rarity == rarity:
				candidates.append(chef)
		# Fall back to any remaining chef when the rolled rarity is sold out.
		var bucket := candidates if not candidates.is_empty() else available
		var picked: ChefCard = bucket[rng.randi_range(0, bucket.size() - 1)]
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
		var chef := ResourceLoader.load(resource_path) as ChefCard
		if chef == null or chef.id.is_empty():
			push_error("ChefCatalog: failed to load %s" % resource_path)
			continue
		if _by_id.has(chef.id):
			continue
		_pool.append(chef)
		_by_id[chef.id] = chef
