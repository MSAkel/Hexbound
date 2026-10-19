class_name StationType
extends Resource

## A station specialisation. A base station turns into this type the first time its regular
## spots hold the required cards. Perks grow with the station level. Level 3 offers a choice.

@export var id: String = ""
@export var display_name: String = ""
@export var icon: Texture2D
## Badge, row tint and perk float colour.
@export var color: Color = Color.WHITE
## Tag -> card count the station needs. TAG_KITCHENWARE counts Kitchenware cards.
@export var required_counts: Dictionary = {}
## Tags in required_counts that must be filled by different cards (two different Meats).
@export var distinct_tags: Array[StringName] = []
## Perk active at levels 1 to 4. Index 0 is level 1. Each one replaces the previous level's perk.
@export var level_perks: Array[StationPerk] = []
## Two options offered at level 3. The pick stays for the rest of the run, on top of the level perk.
@export var choice_options: Array[StationPerk] = []


## True when cards (the station's regular spots) satisfy every requirement.
func is_satisfied_by(cards: Array[TileCard]) -> bool:
	return missing_counts(cards).is_empty()


## Tag -> how many more cards the station needs. Empty when the requirements are met.
func missing_counts(cards: Array[TileCard]) -> Dictionary:
	var missing := {}
	for tag: StringName in required_counts:
		var needed := int(required_counts[tag])
		var have := _count_for_tag(cards, tag)
		if have < needed:
			missing[tag] = needed - have
	return missing


## Kind labels that read the same in the plural ("2 Seafood").
const UNCOUNTABLE_LABELS: Array[String] = [GameTerms.SEAFOOD, GameTerms.DAIRY, GameTerms.KITCHENWARE]


## Player-facing requirements, e.g. "2 different Vegetables · 1 Fruit · 1 Kitchenware".
func get_requirements_text(separator: String = " · ") -> String:
	var parts: PackedStringArray = []
	for tag: StringName in required_counts:
		var count := int(required_counts[tag])
		var label := GameTerms.get_ingredient_kind_label(tag)
		if label.is_empty():
			label = String(tag).capitalize()
		if count > 1 and not label in UNCOUNTABLE_LABELS:
			label += "s"
		if tag in distinct_tags and count > 1:
			label = "different %s" % label
		parts.append("%d %s" % [count, label])
	return separator.join(parts)


## Perk for a level, or null below level 1.
func perk_for_level(level: int) -> StationPerk:
	if level <= 0 or level_perks.is_empty():
		return null
	return level_perks[mini(level, level_perks.size()) - 1]


func _count_for_tag(cards: Array[TileCard], tag: StringName) -> int:
	var ids := {}
	var count := 0
	for card: TileCard in cards:
		if not TileCard.matches_kind_filter(card, tag):
			continue
		if tag in distinct_tags:
			ids[card.id] = true
		else:
			count += 1
	if tag in distinct_tags:
		return ids.size()
	return count
