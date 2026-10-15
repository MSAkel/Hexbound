class_name StationPerk
extends Resource

## One passive a typed station grants at a level. Matches cards seated on that station
## by tag or by id, then adds flat Flavour after they pay and/or scales their whole output.

@export_multiline var description: String = ""
## Matches cards carrying any of these tags. TAG_KITCHENWARE matches by card type.
@export var target_tags: Array[StringName] = []
## Matches these card ids exactly, for perks such as "Steak Flavour is tripled".
@export var target_card_ids: Array[String] = []
## Flat Flavour added after a matching Ingredient pays. Not scaled by Garnish.
@export var flat_flavour: int = 0
## Multiplies a matching card's output for the whole activation. 1.0 means no change.
@export var output_scale: float = 1.0


func matches(card: TileCard) -> bool:
	if card == null:
		return false
	if card.id in target_card_ids:
		return true
	for tag: StringName in target_tags:
		if TileCard.matches_kind_filter(card, tag):
			return true
	return false
