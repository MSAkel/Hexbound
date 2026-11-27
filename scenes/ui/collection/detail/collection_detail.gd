class_name CollectionDetail
extends PanelContainer

## Right side of a Collection page: the parchment panel describing the selected entry. A header
## (icon, tags, name, tagline) and sections that depend on the collection. Each show_* call
## replaces the content and scrolls back to the top. Looks live in the section scenes.

const TAG_SCENE := preload("res://scenes/ui/collection/detail/detail_tag.tscn")
const TEXT_SECTION_SCENE := preload("res://scenes/ui/collection/detail/detail_text_section.tscn")
const INFO_CARDS_SCENE := preload("res://scenes/ui/collection/detail/detail_info_cards.tscn")
const NOTE_SCENE := preload("res://scenes/ui/collection/detail/detail_note.tscn")
const CHIPS_SECTION_SCENE := preload("res://scenes/ui/collection/detail/detail_chips_section.tscn")
const FACTS_SECTION_SCENE := preload("res://scenes/ui/collection/detail/detail_facts_section.tscn")
const KITCHEN_SCENE := preload("res://scenes/ui/collection/detail/detail_kitchen.tscn")
const ROWS_SECTION_SCENE := preload("res://scenes/ui/collection/detail/detail_rows_section.tscn")
const REQUIREMENT_ROW_SCENE := preload("res://scenes/ui/collection/detail/requirement_row.tscn")
const LEVEL_ROW_SCENE := preload("res://scenes/ui/collection/detail/level_row.tscn")
const STATS_SCENE := preload("res://scenes/ui/collection/detail/detail_stats.tscn")
const LOCKED_SECTION_SCENE := preload("res://scenes/ui/collection/detail/detail_locked_section.tscn")

const EVENT_ICON := preload("res://assets/gui/map_layouts/challenge_icon.png")

## Inline stat icons in effect text, drawn this many pixels high.
const STAT_ICON_SIZE := 22
const STAT_TOKEN_PATTERN := "\\{(flavour|mult|gold|garnish)\\}"

@onready var _scroll: ScrollContainer = %Scroll
@onready var _icon_well: Control = %IconWell
@onready var _icon: TextureRect = %Icon
@onready var _tags: HBoxContainer = %Tags
@onready var _name: Label = %Name
@onready var _tagline: Label = %Tagline
@onready var _sections: VBoxContainer = %Sections

static var _stat_token_regex: RegEx


func get_scroll() -> ScrollContainer:
	return _scroll


#region Collections

func show_meal(meal: MealCard) -> void:
	var lore := MealLore.get_entry(meal.id)
	_reset(meal.icon, meal.name, String(lore.get("tagline", "")))
	_add_tag(_meal_kind_label(meal), CollectionDetailTag.Look.KIND)
	if not String(lore.get("origin", "")).is_empty():
		_add_tag(String(lore["origin"]), CollectionDetailTag.Look.PLACE)
	if not lore.is_empty():
		var cards := INFO_CARDS_SCENE.instantiate() as CollectionDetailInfoCards
		_sections.add_child(cards)
		cards.setup(String(lore.get("first_made_by", "")), String(lore.get("where", "")), String(lore.get("when", "")))
		var note := NOTE_SCENE.instantiate() as CollectionDetailNote
		_sections.add_child(note)
		note.setup("[b]%s[/b] %s" % [_escape(String(lore.get("certainty", ""))), _escape(String(lore.get("certainty_note", "")))])
		var meal_stats := CollectionStats.get_meal_stats(meal.id)
		var served := int(meal_stats["served"])
		if bool(meal_stats["story"]):
			_add_text_section("The story", _escape(String(lore.get("story", ""))))
		else:
			_add_locked_section("The story", meal, served, CollectionStats.STORY_UNLOCK_SERVES)
		if bool(meal_stats["facts"]):
			var facts := FACTS_SECTION_SCENE.instantiate() as CollectionDetailFactsSection
			_sections.add_child(facts)
			facts.setup("Fun facts", _strings(lore.get("facts", [])))
		else:
			_add_locked_section("Fun facts", meal, served, CollectionStats.FACTS_UNLOCK_SERVES)
		var ingredients := CHIPS_SECTION_SCENE.instantiate() as CollectionDetailChipsSection
		_sections.add_child(ingredients)
		ingredients.setup("Traditional ingredients", _strings(lore.get("ingredients", [])))
	var stats := _pick_stat_items(CollectionStats.GROUP_CARD, meal.id)
	stats.append(["Times served", str(int(CollectionStats.get_meal_stats(meal.id)["served"]))])
	_add_stats(stats)
	_add_kitchen("In the kitchen", _effect_bbcode(meal.get_description_text()), true, _recipe_slots(meal))


## Ingredients and Kitchenware.
func show_tile_card(card: TileCard) -> void:
	_reset(card.icon, card.name, "")
	_add_tag(GameTerms.get_tile_card_type_label(card), CollectionDetailTag.Look.KIND)
	var kinds := card.get_distinct_recipe_tag_label()
	if not kinds.is_empty():
		_add_tag(kinds, CollectionDetailTag.Look.PLACE)
	_add_kitchen("In the kitchen", _effect_bbcode(card.get_description_text()), false)
	_add_stats(_pick_stat_items(CollectionStats.GROUP_CARD, card.id))


func show_technique(technique: StaffCard) -> void:
	_reset(technique.icon, technique.name, "")
	_add_tag(rarity_label(technique.rarity), CollectionDetailTag.Look.KIND)
	_add_tag("%d Gold" % technique.get_base_price(), CollectionDetailTag.Look.PLACE)
	_add_kitchen("Effect", _effect_bbcode(technique.description), false)
	_add_stats(_pick_stat_items(CollectionStats.GROUP_TECHNIQUE, technique.id))


func show_condiment(condiment: Condiment) -> void:
	_reset(condiment.icon, condiment.display_name, "")
	_add_tag(GameTerms.CONDIMENTS.trim_suffix("s"), CollectionDetailTag.Look.KIND)
	_add_tag("%d Gold" % condiment.base_price, CollectionDetailTag.Look.PLACE)
	_add_kitchen("Effect", _effect_bbcode(condiment.description), false)
	_add_stats(_pick_stat_items(CollectionStats.GROUP_CONDIMENT, condiment.id))


func show_station(station_type: StationType) -> void:
	_reset(station_type.icon, station_type.display_name, "")
	_add_tag("Station", CollectionDetailTag.Look.KIND)
	var requires := _add_rows_section("Requires")
	for requirement: Dictionary in _station_requirements(station_type):
		var row := REQUIREMENT_ROW_SCENE.instantiate() as CollectionRequirementRow
		requires.add_row(row)
		row.setup(requirement["icon"] as Texture2D, String(requirement["text"]))
	var levels := _add_rows_section("Levels")
	for level: int in range(StationManager.START_LEVEL, StationManager.MAX_LEVEL + 1):
		var row := LEVEL_ROW_SCENE.instantiate() as CollectionLevelRow
		levels.add_row(row)
		row.setup("LV %d" % level, _station_level_lines(station_type, level))
	var station_stats := CollectionStats.get_station_stats(station_type.id)
	_add_stats([["Times set", str(int(station_stats["set"]))], ["Wins with", str(int(station_stats["wins"]))]])


func show_chef(chef: ChefDefinition) -> void:
	_reset(chef.icon, chef.display_name, "")
	_add_tag("Chef", CollectionDetailTag.Look.KIND)
	_add_kitchen("Ability", _effect_bbcode(chef.speciality_description), false)
	_add_text_section("Starting deck", _starting_deck_bbcode(chef))
	var signature := ChefRegistry.get_signature_meal_ids(chef)
	if not signature.is_empty():
		var names: Array[String] = []
		for meal_id: String in signature:
			var template := GameManager.get_tile_card_by_id(meal_id)
			names.append(template.name if template != null else meal_id.capitalize())
		var chips := CHIPS_SECTION_SCENE.instantiate() as CollectionDetailChipsSection
		_sections.add_child(chips)
		chips.setup("Signature Meals", names)
	var chef_stats := CollectionStats.get_chef_stats(chef.id)
	var runs := int(chef_stats["runs"])
	var wins := int(chef_stats["wins"])
	var best_level := int(chef_stats["highest_difficulty_won"])
	_add_stats([
		["Runs", str(runs)],
		["Wins", str(wins)],
		["Win rate", _rate_text(wins, runs)],
		["Best Day", str(int(chef_stats["best_day"])) if int(chef_stats["best_day"]) > 0 else "-"],
		["Top level won", str(best_level + 1) if best_level >= 0 else "-"],
	])


func show_event(event_type: EventManager.Type) -> void:
	_reset(EVENT_ICON, EventManager.get_event_name(event_type), "")
	_add_tag("Event", CollectionDetailTag.Look.KIND)
	_add_tag(EventManager.get_allowed_rounds_label(event_type), CollectionDetailTag.Look.PLACE)
	var info: Dictionary = EventManager.EVENT_INFO[event_type]
	_add_kitchen("Effect", _effect_bbcode(String(info.get("description", ""))), false)


## An entry the player has not discovered yet: only "???".
func show_undiscovered() -> void:
	_reset(null, CollectionTile.UNDISCOVERED_NAME, "")
	_icon_well.visible = false

#endregion


#region Labels used by the list too

static func rarity_label(rarity: Card.Rarity) -> String:
	var key: Variant = Card.Rarity.find_key(rarity)
	return String(key).capitalize() if key != null else ""


## Dish or Beverage, from the Meal's own tags.
static func meal_kind_label(meal: MealCard) -> String:
	if meal.has_authored_ingredient_tag(TileCard.TAG_BEVERAGE):
		return GameTerms.get_ingredient_kind_label(TileCard.TAG_BEVERAGE)
	return GameTerms.DISH

#endregion


func _meal_kind_label(meal: MealCard) -> String:
	return meal_kind_label(meal)


func _reset(icon_texture: Texture2D, display_name: String, tagline: String) -> void:
	for child in _tags.get_children():
		_tags.remove_child(child)
		child.queue_free()
	for child in _sections.get_children():
		_sections.remove_child(child)
		child.queue_free()
	_icon_well.visible = true
	_icon.texture = icon_texture
	_name.text = display_name
	_tagline.text = tagline
	_tagline.visible = not tagline.is_empty()
	_scroll.scroll_vertical = 0
	_scroll.set_deferred("scroll_vertical", 0)


func _add_tag(text: String, look: CollectionDetailTag.Look) -> void:
	if text.is_empty():
		return
	var tag := TAG_SCENE.instantiate() as CollectionDetailTag
	_tags.add_child(tag)
	tag.setup(text, look)


func _add_text_section(heading: String, body_bbcode: String) -> void:
	if body_bbcode.is_empty():
		return
	var section := TEXT_SECTION_SCENE.instantiate() as CollectionDetailTextSection
	_sections.add_child(section)
	section.setup(heading, body_bbcode)


func _add_kitchen(heading: String, effect_bbcode: String, show_recipe: bool, slots: Array[Dictionary] = []) -> void:
	var kitchen := KITCHEN_SCENE.instantiate() as CollectionDetailKitchen
	_sections.add_child(kitchen)
	kitchen.setup(heading, effect_bbcode, show_recipe, slots)


func _add_stats(items: Array) -> void:
	var strip := STATS_SCENE.instantiate() as CollectionDetailStats
	_sections.add_child(strip)
	strip.setup(items)


func _add_locked_section(heading: String, meal: MealCard, served: int, goal: int) -> void:
	var section := LOCKED_SECTION_SCENE.instantiate() as CollectionDetailLockedSection
	_sections.add_child(section)
	section.setup(heading, "Serve %s %d times to unlock" % [meal.name, goal], served, goal)


## Picked, Wins with and win rate (wins out of the runs it ended in) for a card, Technique or Condiment.
func _pick_stat_items(group: String, id: String) -> Array:
	var stats := CollectionStats.get_pick_stats(group, id)
	return [
		["Picked", str(int(stats["picked"]))],
		["Wins with", str(int(stats["wins"]))],
		["Win rate", _rate_text(int(stats["wins"]), int(stats["final_runs"]))],
	]


func _rate_text(wins: int, runs: int) -> String:
	if runs <= 0:
		return "-"
	return "%d%%" % roundi(100.0 * wins / runs)


func _add_rows_section(heading: String) -> CollectionDetailRowsSection:
	var section := ROWS_SECTION_SCENE.instantiate() as CollectionDetailRowsSection
	_sections.add_child(section)
	section.setup(heading)
	return section


## Named cards first (solid), then one dashed slot per card of a kind.
func _recipe_slots(meal: MealCard) -> Array[Dictionary]:
	var slots: Array[Dictionary] = []
	for card_id: String in meal.recipe_required_card_ids:
		var template := GameManager.get_tile_card_by_id(card_id)
		slots.append({
			"icon": template.icon if template != null else FeastStatIcons.PLACEHOLDER,
			"text": template.name if template != null else card_id.capitalize(),
			"any": false,
		})
	var counts := meal.get_recipe_kind_counts()
	for tag: StringName in counts:
		for _i in int(counts[tag]):
			slots.append({
				"icon": FeastStatIcons.get_ingredient_kind_icon(tag),
				"text": GameTerms.get_ingredient_kind_label(tag),
				"any": true,
			})
	return slots


## One row per requirement: {"icon", "text"}. Named cards show their own art, kinds
## the kind icon (placeholders for now), "any Ingredient" the placeholder icon.
func _station_requirements(station_type: StationType) -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for card_id: String in station_type.required_card_ids:
		var template := GameManager.get_tile_card_by_id(card_id)
		rows.append({
			"icon": template.icon if template != null and template.icon != null else FeastStatIcons.PLACEHOLDER,
			"text": template.name if template != null else card_id.capitalize(),
		})
	for tag: StringName in station_type.required_counts:
		var count := int(station_type.required_counts[tag])
		var text := ""
		var icon_texture: Texture2D = FeastStatIcons.PLACEHOLDER
		if tag == StationType.TAG_ANY_INGREDIENT:
			text = "%d kinds of %s" % [count, GameTerms.INGREDIENT] if tag in station_type.distinct_tags else "%d any %s" % [count, GameTerms.INGREDIENT]
		else:
			var label := GameTerms.get_ingredient_kind_label(tag)
			if label.is_empty():
				label = String(tag).capitalize()
			if count > 1 and not label in StationType.UNCOUNTABLE_LABELS:
				label += "s"
			text = "%d %s" % [count, label]
			icon_texture = FeastStatIcons.get_ingredient_kind_icon(tag)
		rows.append({"icon": icon_texture, "text": text})
	return rows


## Everything reaching a level gives a Station, one line each.
func _station_level_lines(station_type: StationType, level: int) -> PackedStringArray:
	var lines: PackedStringArray = []
	var upgrade := station_type.get_level_upgrade_text(level)
	if not upgrade.is_empty():
		lines.append(CardKeywordGlossary.to_plain(upgrade))
	if level == StationManager.MEAL_SLOT_UNLOCK_LEVEL:
		lines.append("Opens a locked second %s (higher difficulty levels)." % GameTerms.MEAL_SLOT)
	var options: Array[StationPerk] = []
	if level == StationManager.CHOICE_LEVEL:
		options = station_type.choice_options
	elif level == StationManager.CAPSTONE_LEVEL:
		options = station_type.capstone_options
	if not options.is_empty():
		lines.append("Choose one perk:")
	for perk: StationPerk in options:
		lines.append("• %s" % CardKeywordGlossary.to_plain(perk.description))
	if lines.is_empty():
		lines.append("-")
	return lines


func _starting_deck_bbcode(chef: ChefDefinition) -> String:
	if not chef.has_station_deck():
		return "Every %s and %s." % [GameTerms.INGREDIENT, GameTerms.KITCHENWARE]
	var signature := ChefRegistry.get_signature_meal_ids(chef).size()
	var random := ChefRegistry.STARTING_MEAL_COUNT - signature
	var meals := "%d random Meals" % random
	if signature > 0:
		meals = "%d signature Meals and %d random Meals" % [signature, random]
	var stations: PackedStringArray = []
	for entry: String in chef.deck_stations:
		stations.append(_deck_station_label(entry))
	return "Every %s and %s, plus %s.\nKit Stations: %s." % [
		GameTerms.INGREDIENT, GameTerms.KITCHENWARE, meals, ", ".join(stations),
	]


func _deck_station_label(entry: String) -> String:
	var choices := ChefRegistry.get_deck_station_choices(entry)
	var names: PackedStringArray = []
	for station_id: String in choices:
		if station_id == ChefDefinition.ANY_STATION:
			return "any Station"
		names.append(_station_name(station_id))
	if names.size() == 1:
		return names[0]
	return "one of %s" % " / ".join(names)


func _station_name(station_id: String) -> String:
	for station_type: StationType in StationManager.get_station_types():
		if station_type.id == station_id:
			return station_type.display_name
	return station_id.capitalize()


## Card text as BBCode: glossary words coloured, with the Flavour / Mult / Gold / Garnish icon in
## front of their word.
func _effect_bbcode(source: String) -> String:
	if _stat_token_regex == null:
		_stat_token_regex = RegEx.create_from_string(STAT_TOKEN_PATTERN)
	var result := ""
	var cursor := 0
	for regex_match: RegExMatch in _stat_token_regex.search_all(source):
		result += CardKeywordGlossary.to_bbcode(source.substr(cursor, regex_match.get_start() - cursor))
		result += FeastStatIcons.inline_bbcode(_stat_icon(regex_match.get_string(1)), STAT_ICON_SIZE)
		result += CardKeywordGlossary.to_bbcode(regex_match.get_string())
		cursor = regex_match.get_end()
	result += CardKeywordGlossary.to_bbcode(source.substr(cursor))
	return result


func _stat_icon(token: String) -> Texture2D:
	match token:
		"flavour":
			return FeastStatIcons.FLAVOUR
		"mult":
			return FeastStatIcons.MULT
		"gold":
			return FeastStatIcons.GOLD
		"garnish":
			return FeastStatIcons.GARNISH
	return null


func _strings(values: Variant) -> Array[String]:
	var result: Array[String] = []
	if values is Array:
		for value: Variant in values:
			result.append(String(value))
	return result


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
