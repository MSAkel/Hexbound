class_name ChefProgression
extends RefCounted

## Chef XP and chef levels (meta progression, project doc "Flavour Pass: Meta Progression Design").
## XP is per chef, stored in CollectionStats and added once at run end; the chef level is derived
## from it and shown on the chef selection screen. Each level gives a reward the chef page in the
## Collection shows: signature cards, bio parts and an alternate outfit, defined per chef in
## resources/chef_rewards.json, with bio text in resources/chef_bios.json. Content not written yet
## shows as locked slots at its level. All numbers are untuned except levels 5 and 6 (set by the user).

const REWARDS_PATH := "res://resources/chef_rewards.json"
const BIOS_PATH := "res://resources/chef_bios.json"
const PLACEHOLDER_PATH := "res://resources/debug/chef_rewards_placeholder.json"
## Debug builds only: pass this after `--` to show the placeholder rewards (on the Pitmaster) so the
## chef page can be built before any real content exists.
const PLACEHOLDER_ARG := "--chef-rewards-placeholder"

## Total XP needed for each chef level, from level 1.
const LEVEL_XP: Array[int] = [0, 100, 300, 600, 1500, 3000]
const MAX_LEVEL := 6
const XP_PER_DAY_CLEARED := 10
const XP_PER_WIN := 50
## Each difficulty level above Level 1 adds this much to the run's XP (Level 8 = x1.7).
const XP_DIFFICULTY_STEP := 0.1

## Chef levels of each reward (user, Nov 27). A chef with no content written still shows these
## slots, locked.
const SIGNATURE_CARD_LEVELS: Array[int] = [2, 4]
const BIO_PART_LEVELS: Array[int] = [3, 5]
const OUTFIT_LEVEL := 6

static var _rewards: Dictionary = {}
static var _bios: Dictionary = {}
static var _loaded := false
## Set by debug tools and checks to force the placeholder rewards on or off.
static var placeholders_override: int = -1


#region XP and levels

## XP a run pays: Days cleared and the win, scaled by difficulty (a Difficulty.Level index).
static func run_xp(days_cleared: int, is_win: bool, difficulty: int) -> int:
	var base := maxi(days_cleared, 0) * XP_PER_DAY_CLEARED + (XP_PER_WIN if is_win else 0)
	return roundi(base * (1.0 + XP_DIFFICULTY_STEP * maxi(difficulty, 0)))


static func level_for_xp(xp: int) -> int:
	var level := 1
	for index in LEVEL_XP.size():
		if xp >= LEVEL_XP[index]:
			level = index + 1
	return mini(level, MAX_LEVEL)


## The chef level that decides which rewards show: the real level, or MAX_LEVEL on a profile with
## Unlock all (ProfileManager). The XP bar and stats keep showing the real level.
static func reward_level_for_xp(xp: int) -> int:
	if ProfileManager.is_unlock_all():
		return MAX_LEVEL
	return level_for_xp(xp)


## Total XP that reaches a level (1-based).
static func xp_for_level(level: int) -> int:
	return LEVEL_XP[clampi(level, 1, MAX_LEVEL) - 1]

#endregion


#region Difficulty unlocks

## Difficulty levels unlock per chef (user, Nov 28): Level 1 is always open, and winning a run on a
## level opens the next one for that chef only. Built on CollectionStats' highest_difficulty_won, so
## wins from before this change count. Unlock all opens every level. A locked chef (see Chef
## unlocks) has only Level 1.
static func highest_unlocked_difficulty(chef_id: String) -> int:
	var last := Difficulty.get_all_levels().size() - 1
	if ProfileManager.is_unlock_all():
		return last
	if not is_chef_unlocked(chef_id):
		return 0
	var won := int(CollectionStats.get_chef_stats(chef_id).get("highest_difficulty_won", -1))
	return clampi(won + 1, 0, last)


## level is a Difficulty.Level index. A locked chef has only Level 1.
static func is_difficulty_unlocked(chef_id: String, level: int) -> bool:
	return level <= highest_unlocked_difficulty(chef_id)

#endregion


#region Chef unlocks

## How each chef unlocks (user, Nov 28; project doc "Flavour Pass: Chef Unlocks Design"). An empty
## entry is open from the start. Otherwise the chef unlocks on a win (any chef, any difficulty) with:
## "station": that Station type on the board at the win; "gold": at least that much Gold held at the
## win; "all_other_chefs": a win with every other chef since unlocks began. The chef selection
## screen's condition text and the run-end check both read this table. Wins from before chef unlocks
## existed don't count, and seeded runs never count (CollectionStats).
const CHEF_UNLOCKS: Dictionary[String, Dictionary] = {
	"sous_chef": {},
	"sommelier": {"station": "bar_station"},
	"forager": {"station": "cold_station"},
	"fishmonger": {"station": "fish_station"},
	"pitmaster": {"station": "grilling_station"},
	"pastry_chef": {"station": "pastry_station"},
	"restaurateur": {"gold": 100},
	"chef_de_cuisine": {"all_other_chefs": true},
}


## Unlock all opens every chef. A chef missing from CHEF_UNLOCKS is open (the content check flags it).
static func is_chef_unlocked(chef_id: String) -> bool:
	if ProfileManager.is_unlock_all() or is_chef_open_from_start(chef_id):
		return true
	return CollectionStats.is_chef_unlock_stored(chef_id)


static func is_chef_open_from_start(chef_id: String) -> bool:
	return (CHEF_UNLOCKS.get(chef_id, {}) as Dictionary).is_empty()


## The chef selection screen's text for a locked chef, e.g. "Win a run with a Bar Station on the
## board."
static func get_unlock_condition_text(chef_id: String) -> String:
	var rule: Dictionary = CHEF_UNLOCKS.get(chef_id, {})
	if rule.has("station"):
		return "Win a run with a %s on the board." % _station_name(String(rule["station"]))
	if rule.has("gold"):
		return "Win a run holding %d or more Gold." % int(rule["gold"])
	if rule.has("all_other_chefs"):
		return "Win a run with each of the other %d chefs." % (CHEF_UNLOCKS.size() - 1)
	return ""


## Chefs this win unlocks, whether or not they were unlocked before (the caller keeps the stored ones).
## win: {"stations": station type ids on the board, "gold": Gold held}. won_chefs: every chef won
## with since unlocks began, this win's chef included.
static func check_chef_unlocks(win: Dictionary, won_chefs: Array[String]) -> Array[String]:
	var stations: Array = win.get("stations", [])
	var gold := int(win.get("gold", 0))
	var unlocked: Array[String] = []
	for chef_id: String in CHEF_UNLOCKS:
		var rule: Dictionary = CHEF_UNLOCKS[chef_id]
		if rule.is_empty():
			continue
		var met := true
		if rule.has("station") and String(rule["station"]) not in stations:
			met = false
		if rule.has("gold") and gold < int(rule["gold"]):
			met = false
		if rule.has("all_other_chefs"):
			for other_id: String in CHEF_UNLOCKS:
				if other_id != chef_id and other_id not in won_chefs:
					met = false
		if met:
			unlocked.append(chef_id)
	return unlocked


## "Bar" reads "Bar Station"; names that already say Station stay as they are.
static func _station_name(station_id: String) -> String:
	var station_type := StationManager.get_station_type_by_id(station_id)
	var station_name := station_type.display_name if station_type != null else station_id.capitalize()
	return station_name if station_name.ends_with("Station") else "%s Station" % station_name

#endregion


#region Rewards

## Signature cards in unlock order: [{"card_id", "level"}]. Without authored entries, one slot per
## SIGNATURE_CARD_LEVELS with an empty card_id.
static func get_signature_cards(chef_id: String) -> Array[Dictionary]:
	var cards := _entries(chef_id, "signature_cards")
	if cards.is_empty():
		for level: int in SIGNATURE_CARD_LEVELS:
			cards.append({"card_id": "", "level": level})
	return cards


## Bio parts in order: [{"part", "level", "text"}]. Text comes from chef_bios.json and is empty
## until written. Without authored entries, one part per BIO_PART_LEVELS.
static func get_bio_parts(chef_id: String) -> Array[Dictionary]:
	var parts := _entries(chef_id, "bio_parts")
	if parts.is_empty():
		for index in BIO_PART_LEVELS.size():
			parts.append({"part": index + 1, "level": BIO_PART_LEVELS[index]})
	var texts: Variant = _chef_bio(chef_id).get("parts", [])
	for part: Dictionary in parts:
		var index := int(part.get("part", 0)) - 1
		part["text"] = String((texts as Array)[index]) if texts is Array and index >= 0 and index < (texts as Array).size() else ""
	return parts


## {"level", "name", "portrait", "tint"}. name is empty while the chef has no outfit yet. portrait
## is a res:// path to the recoloured portrait; until it exists, tint recolours the base portrait.
static func get_outfit(chef_id: String) -> Dictionary:
	var outfit: Variant = _chef_rewards(chef_id).get("outfit", {})
	var result: Dictionary = (outfit as Dictionary).duplicate() if outfit is Dictionary else {}
	if not result.has("level"):
		result["level"] = OUTFIT_LEVEL
	return result


## Card ids of the signature cards a chef level has reached.
static func get_unlocked_signature_card_ids(chef_id: String, level: int) -> Array[String]:
	var ids: Array[String] = []
	for entry: Dictionary in get_signature_cards(chef_id):
		if int(entry.get("level", MAX_LEVEL + 1)) <= level and not String(entry.get("card_id", "")).is_empty():
			ids.append(String(entry.get("card_id", "")))
	return ids


static func uses_placeholders() -> bool:
	if placeholders_override >= 0:
		return placeholders_override == 1
	return OS.is_debug_build() and PLACEHOLDER_ARG in OS.get_cmdline_user_args()


## Reloads the data files (after placeholders_override changes).
static func reload_data() -> void:
	_loaded = false
	_ensure_loaded()


static func _entries(chef_id: String, key: String) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	var list: Variant = _chef_rewards(chef_id).get(key, [])
	if list is Array:
		for entry: Variant in list:
			if entry is Dictionary:
				result.append((entry as Dictionary).duplicate())
	result.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a.get("level", 0)) < int(b.get("level", 0)))
	return result


static func _chef_rewards(chef_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Variant = _rewards.get(chef_id, {})
	return entry as Dictionary if entry is Dictionary else {}


static func _chef_bio(chef_id: String) -> Dictionary:
	_ensure_loaded()
	var entry: Variant = _bios.get(chef_id, {})
	return entry as Dictionary if entry is Dictionary else {}


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_rewards = _read_chefs(REWARDS_PATH)
	_bios = _read_chefs(BIOS_PATH)
	if uses_placeholders():
		var placeholder := _read_json(PLACEHOLDER_PATH)
		for chef_id: String in _dictionary(placeholder.get("rewards")):
			_rewards[chef_id] = placeholder["rewards"][chef_id]
		for chef_id: String in _dictionary(placeholder.get("bios")):
			_bios[chef_id] = placeholder["bios"][chef_id]


static func _read_chefs(path: String) -> Dictionary:
	return _dictionary(_read_json(path).get("chefs")).duplicate(true)


static func _read_json(path: String) -> Dictionary:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		push_error("ChefProgression: could not open %s." % path)
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is Dictionary:
		return parsed
	push_error("ChefProgression: %s is not a JSON object." % path)
	return {}


static func _dictionary(value: Variant) -> Dictionary:
	return value as Dictionary if value is Dictionary else {}

#endregion
