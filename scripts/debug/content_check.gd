extends Node

## Content sanity check for CI: fails when content a shop depends on loads empty.
## Empty content raises no error. A moved Technique folder once left the catalog empty, the
## merchant's Technique slot vanished, and every other check stayed green.
## Prints [content] lines and exits 1 when any check fails.
##   godot --headless --path . res://scenes/debug/content_check.tscn

var _failures := 0


func _ready() -> void:
	# One frame so the autoloads finish their own setup.
	await get_tree().process_frame
	_check_techniques()
	_check_condiments()
	_check_tile_pool()
	_check_merchant_shelf()
	_check_chef_rewards()
	_check_unlock_all()
	if _failures > 0:
		print("[content] FAILED: %d check(s)" % _failures)
	else:
		print("[content] all checks passed")
	get_tree().quit(1 if _failures > 0 else 0)


func _check(check_name: String, passed: bool, detail: String) -> void:
	if passed:
		print("[content] PASS %s: %s" % [check_name, detail])
		return
	_failures += 1
	print("[content] FAIL %s: %s" % [check_name, detail])
	# Also an ERROR: line, which godot_checks.sh's log scan treats as a failure.
	push_error("Content check failed: %s (%s)" % [check_name, detail])


func _check_techniques() -> void:
	var count := StaffCatalog.get_all().size()
	_check("Technique catalog", count > 0, "%d Techniques loaded" % count)


func _check_condiments() -> void:
	var count := CondimentCatalog.get_all().size()
	_check("Condiment catalog", count > 0, "%d condiments loaded" % count)


## The merchant, card picks and packs draw from these. A type with no cards hides its pack.
func _check_tile_pool() -> void:
	var counts := {
		TileCard.TileCardType.INGREDIENT: 0,
		TileCard.TileCardType.KITCHENWARE: 0,
		TileCard.TileCardType.MEAL: 0,
	}
	for tile_card in GameManager.tile_cards_pool:
		if counts.has(tile_card.type):
			counts[tile_card.type] += 1
	var detail := "%d Ingredients, %d Kitchenware, %d Meals" % [
		counts[TileCard.TileCardType.INGREDIENT],
		counts[TileCard.TileCardType.KITCHENWARE],
		counts[TileCard.TileCardType.MEAL],
	]
	var all_present := true
	for type_count: int in counts.values():
		all_present = all_present and type_count > 0
	_check("Tile card pool", all_present, detail)


## The exact symptom: the merchant fills its shelf, has a Technique to offer, and a Chef's Notebook can open.
func _check_merchant_shelf() -> void:
	var stock := Merchant.draw_shelf_stock(0)
	_check("Merchant shelf", stock.size() == Merchant.shelf_card_count(), "%d drawn" % stock.size())
	var techniques := StaffCatalog.draw(1, RandomNumberGenerator.new())
	_check("Merchant Technique stock", techniques.size() == 1, "%d drawn" % techniques.size())
	var notebook := MerchantPacks.draw_contents(MerchantPacks.Kind.TECHNIQUES, 0, 0)
	_check(
		"Chef's Notebook contents",
		notebook.size() == MerchantPacks.CARD_COUNT,
		"%d of %d Techniques" % [notebook.size(), MerchantPacks.CARD_COUNT]
	)


## Chef level rewards (ChefProgression): every written signature card exists and every reward
## level is a real chef level. The debug placeholder set is checked too, so the
## page it builds stays valid.
func _check_chef_rewards() -> void:
	for placeholders: int in [0, 1]:
		ChefProgression.placeholders_override = placeholders
		ChefProgression.reload_data()
		var problems: Array[String] = []
		var rewards := 0
		for chef: ChefDefinition in ChefRegistry.get_all_chefs():
			# Rewards not written yet (empty card id, text or name) show as locked slots.
			for entry: Dictionary in ChefProgression.get_signature_cards(chef.id):
				var card_id := String(entry.get("card_id", ""))
				if not card_id.is_empty():
					rewards += 1
					if GameManager.get_tile_card_by_id(card_id) == null:
						problems.append("%s: no card %s" % [chef.id, card_id])
				_check_reward_level(problems, chef.id, entry)
			for part: Dictionary in ChefProgression.get_bio_parts(chef.id):
				if not String(part.get("text", "")).is_empty():
					rewards += 1
				_check_reward_level(problems, chef.id, part)
			var outfit := ChefProgression.get_outfit(chef.id)
			if not String(outfit.get("name", "")).is_empty():
				rewards += 1
			_check_reward_level(problems, chef.id, outfit)
		var label := "Chef rewards (placeholder)" if placeholders == 1 else "Chef rewards"
		_check(label, problems.is_empty(), "%d rewards" % rewards if problems.is_empty() else "; ".join(problems))
	ChefProgression.placeholders_override = -1
	ChefProgression.reload_data()


func _check_reward_level(problems: Array[String], chef_id: String, entry: Dictionary) -> void:
	var level := int(entry.get("level", 0))
	if level < 2 or level > ChefProgression.MAX_LEVEL:
		problems.append("%s: reward at chef level %d" % [chef_id, level])


## Unlock all (ProfileManager) must open every lock the game has: chef rewards, Meal Story and Fun
## facts, "???" Meals and difficulty levels. A new lock that skips is_unlock_all() should get a line here.
func _check_unlock_all() -> void:
	var problems: Array[String] = []
	ProfileManager.unlock_all_override = 1
	if ChefProgression.reward_level_for_xp(0) != ChefProgression.MAX_LEVEL:
		problems.append("chef rewards stay at level %d" % ChefProgression.reward_level_for_xp(0))
	var meal_id := ""
	for card: TileCard in GameManager.tile_cards_pool:
		if card is MealCard:
			meal_id = card.id
			break
	var meal := CollectionStats.get_meal_stats(meal_id)
	for key: String in ["story", "facts", "discovered"]:
		if not bool(meal[key]):
			problems.append("Meal %s stays locked" % key)
	var last_difficulty := Difficulty.get_all_levels().size() - 1
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		if not ChefProgression.is_difficulty_unlocked(chef.id, last_difficulty):
			problems.append("difficulty Level %d stays locked for %s" % [last_difficulty + 1, chef.id])
		if not ChefProgression.is_chef_unlocked(chef.id):
			problems.append("chef %s stays locked" % chef.id)
	ProfileManager.unlock_all_override = 0
	if ChefProgression.reward_level_for_xp(0) != 1:
		problems.append("chef rewards unlocked without the flag")
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		if not ChefProgression.is_difficulty_unlocked(chef.id, 0):
			problems.append("difficulty Level 1 locked for %s" % chef.id)
	ProfileManager.unlock_all_override = -1
	_check("Unlock all", problems.is_empty(), "every lock opens" if problems.is_empty() else "; ".join(problems))
	_check_chef_unlocks()


## Every chef has an unlock rule, the condition texts exist, and the rules unlock what they say.
## Headless runs never read or write the profile's stats, so stored unlocks are empty here and only
## the open-from-start chefs may be open.
func _check_chef_unlocks() -> void:
	var problems: Array[String] = []
	var all_ids: Array[String] = []
	ProfileManager.unlock_all_override = 0
	for chef: ChefDefinition in ChefRegistry.get_all_chefs():
		all_ids.append(chef.id)
		if not ChefProgression.CHEF_UNLOCKS.has(chef.id):
			problems.append("%s has no unlock rule" % chef.id)
			continue
		var open := ChefProgression.is_chef_open_from_start(chef.id)
		if open != (chef.id == "sous_chef"):
			problems.append("%s open from start: %s" % [chef.id, open])
		if ChefProgression.is_chef_unlocked(chef.id) != open:
			problems.append("%s unlocked without a win" % chef.id)
		if not open and ChefProgression.get_unlock_condition_text(chef.id).is_empty():
			problems.append("%s has no condition text" % chef.id)
		var rule: Dictionary = ChefProgression.CHEF_UNLOCKS[chef.id]
		if rule.has("station") and StationManager.get_station_type_by_id(String(rule["station"])) == null:
			problems.append("%s needs unknown Station %s" % [chef.id, rule["station"]])
	ProfileManager.unlock_all_override = -1
	for chef_id: String in ChefProgression.CHEF_UNLOCKS:
		if chef_id not in all_ids:
			problems.append("unlock rule for unknown chef %s" % chef_id)
	var by_bar := ChefProgression.check_chef_unlocks({"stations": ["bar_station", "pastry_station"], "gold": 100}, ["sous_chef"])
	by_bar.sort()
	if by_bar != (["pastry_chef", "restaurateur", "sommelier"] as Array[String]):
		problems.append("a Bar + Pastry win with 100 Gold unlocks %s" % [by_bar])
	var others := all_ids.filter(func(id: String) -> bool: return id != "chef_de_cuisine")
	var won_others: Array[String] = []
	won_others.assign(others)
	if "chef_de_cuisine" not in ChefProgression.check_chef_unlocks({}, won_others):
		problems.append("winning with every other chef doesn't unlock the Chef de Cuisine")
	won_others.erase("restaurateur")
	if "chef_de_cuisine" in ChefProgression.check_chef_unlocks({}, won_others):
		problems.append("the Chef de Cuisine unlocks without a Restaurateur win")
	_check("Chef unlocks", problems.is_empty(), "%d chefs have rules" % all_ids.size() if problems.is_empty() else "; ".join(problems))
