class_name StationPerk
extends Resource

## One passive a typed station grants at a level. Plain perks match cards seated on that station
## by tag, id or Meal category, then add flat Flavour to their base and/or scale their whole output.
## Perks with more behaviour (level 3 and level 6 picks) extend this script and override the hooks.
## seg is always the row of the station that owns the perk. StationManager calls every hook.

@export_multiline var description: String = ""
## Matches cards carrying any of these tags. TAG_KITCHENWARE matches by card type.
@export var target_tags: Array[StringName] = []
## Matches these card ids exactly, for perks such as "Steak Flavour is tripled".
@export var target_card_ids: Array[String] = []
## Matches Meals in any of these categories (MealCard.MealCategory values).
@export var target_meal_categories: Array[int] = []
## Flat Flavour added to a matching Ingredient's base amount, before every multiplier.
@export var flat_flavour: int = 0
## Multiplies a matching card's output for the whole activation. 1.0 means no change.
@export var output_scale: float = 1.0
## Card picks and the merchant draw cards with these tags (or Meals in these categories)
## draw_weight times as often while this perk is active. 1.0 means no change.
@export var draw_tags: Array[StringName] = []
@export var draw_meal_categories: Array[int] = []
@export var draw_weight: float = 1.0


func matches(card: TileCard) -> bool:
	if card == null:
		return false
	if card.id in target_card_ids:
		return true
	for tag: StringName in target_tags:
		if TileCard.matches_kind_filter(card, tag):
			return true
	if not target_meal_categories.is_empty():
		var meal := card as MealCard
		if meal != null and int(meal.meal_category) in target_meal_categories:
			return true
	return false


## Draw weight this perk gives a card in card picks and at the merchant.
func draw_weight_for(card: TileCard) -> float:
	if is_equal_approx(draw_weight, 1.0) or card == null:
		return 1.0
	for tag: StringName in draw_tags:
		if TileCard.matches_kind_filter(card, tag):
			return draw_weight
	var meal := card as MealCard
	if meal != null and int(meal.meal_category) in draw_meal_categories:
		return draw_weight
	return 1.0


#region --- Hooks (override in perk scripts) ---

## Flat Flavour for a card seated on this perk's own station.
func flat_flavour_on_station(_seg: int, _tile: Hex, card: TileCard) -> int:
	return flat_flavour if matches(card) else 0


## Output scale for a card seated on this perk's own station.
func output_scale_on_station(_seg: int, _tile: Hex, card: TileCard) -> float:
	return output_scale if matches(card) else 1.0


## Flat Flavour this station lends to a card on another station (card_seg != seg).
func flat_flavour_elsewhere(_seg: int, _card_seg: int, _tile: Hex, _card: TileCard) -> int:
	return 0


## Output scale this station lends to a card on another station (card_seg != seg).
func output_scale_elsewhere(_seg: int, _card_seg: int, _tile: Hex, _card: TileCard) -> float:
	return 1.0


## Right before a card on this station triggers, before its output is worked out.
func before_card_triggers(_seg: int, _tile: Hex, _card: TileCard) -> void:
	pass


## Right after a card on this station has triggered.
func after_card_triggered(_seg: int, _tile: Hex, _card: TileCard) -> void:
	pass


## A Meal was served on any station (meal_seg may differ from seg). Called while the Meal resolves.
func on_meal_served(_seg: int, _meal_seg: int, _tile: Hex, _meal: MealCard) -> void:
	pass


## Before the first card of the Hour triggers.
func on_hour_started(_seg: int) -> void:
	pass


func on_day_started(_seg: int) -> void:
	pass


## After the last Hour of the Day, before Garnishes are cleared.
func on_day_ended(_seg: int) -> void:
	pass


## Extra Garnish stacks a Garnish given to a card on this station by a Sauce & Dip meal counts for.
func extra_sauce_garnish_stacks(_seg: int, _source_seg: int) -> int:
	return 0


## True when a Meal on this station counts as an extra category (Fish & Chips: Seafood counts as Side).
func meal_counts_as(_seg: int, _meal: MealCard, _category: int) -> bool:
	return false


## True when the Deep Fryer triggers this Ingredient on this station once more (Tempura).
func gets_extra_fryer_trigger(_seg: int, _card: TileCard) -> bool:
	return false


## True when Beverages on this station also count as served on the station at other_seg (Pairing).
func shares_beverages_with(_seg: int, _other_seg: int) -> bool:
	return false

#endregion --- Hooks ---
