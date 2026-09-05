class_name DishCard
extends TileCard

## Seated plate. Reads the N spots immediately before it in fire order, never the whole course.
## Those seats are a bag of tags. Empty or wrong cards break the dish. No skipping gaps.
## On a match, this card plates a local meal pile. It never writes course-wide ×Mult.

## Dish recipe bag. Prefix length is the sum of these counts.
@export var recipe_vegetable_count: int = 0
@export var recipe_fruit_count: int = 0
@export var recipe_grain_count: int = 0
@export var recipe_protein_count: int = 0
@export var recipe_seasoning_count: int = 0
@export var recipe_kitchenware_count: int = 0


func get_trigger_preview_coords(hover_tile: Hex) -> Array[Vector2i]:
	return _coords_for_immediately_previous_hexes(hover_tile, get_recipe_prefix_size())


## Prefix seats holding a card whose tag this dish can use. Gold even if the bag is incomplete.
func get_trigger_preview_gold_coords(hover_tile: Hex) -> Array[Vector2i]:
	var gold: Array[Vector2i] = []
	for hex: Hex in _get_immediately_previous_hexes(hover_tile, get_recipe_prefix_size()):
		if hex.active_tile_card == null:
			continue
		if card_matches_needed_tag(hex.active_tile_card):
			gold.append(hex.coordinates)
	return gold


## Occupied prefix seats whose tags cannot fill this dish's recipe.
func get_trigger_preview_invalid_coords(hover_tile: Hex) -> Array[Vector2i]:
	var invalid: Array[Vector2i] = []
	for hex: Hex in _get_immediately_previous_hexes(hover_tile, get_recipe_prefix_size()):
		if hex.active_tile_card == null:
			continue
		if card_matches_needed_tag(hex.active_tile_card):
			continue
		invalid.append(hex.coordinates)
	return invalid


## True when this card's tag could fill at least one slot in the recipe bag.
func card_matches_needed_tag(card: TileCard) -> bool:
	if card == null or get_recipe_prefix_size() <= 0:
		return false
	if recipe_kitchenware_count > 0 and card.type == TileCardType.KITCHENWARE:
		return true
	match card.ingredient_kind:
		IngredientKind.VEGETABLE:
			return recipe_vegetable_count > 0
		IngredientKind.FRUIT:
			return recipe_fruit_count > 0
		IngredientKind.GRAIN:
			return recipe_grain_count > 0
		IngredientKind.PROTEIN:
			return recipe_protein_count > 0
		IngredientKind.SEASONING:
			return recipe_seasoning_count > 0
		_:
			return false


func get_board_chip(tile: Hex = null) -> Dictionary:
	if tile == null:
		return _stat_board_chip()
	var plated := _compute_plated_outputs(tile)
	if plated.is_empty():
		return _stat_board_chip()
	var flavour := int(plated.get("flavour", 0))
	var additive_mult := float(plated.get("additive_mult", 0.0))
	var has_flavour := flavour > 0
	var has_mult := not is_zero_approx(additive_mult)
	if has_flavour and has_mult:
		return _dual_amount_board_chip(flavour, additive_mult)
	if has_mult:
		return _amount_board_chip_float(additive_mult, ICON_MULT)
	return _amount_board_chip(flavour, ICON_FLAVOUR)


func _on_activate_tile_card(tile: Hex) -> void:
	var recipe := get_matched_prefix_recipe(tile)
	if recipe.is_empty():
		failed_tile_card_text(tile)
		return
	var flavour := _plated_flavour_from_recipe(recipe)
	var additive_mult := _plated_additive_mult_from_recipe(recipe)
	if flavour > 0:
		add_score(tile, flavour)
	if not is_zero_approx(additive_mult):
		add_additive_mult(tile, additive_mult)
	if flavour <= 0 and is_zero_approx(additive_mult):
		failed_tile_card_text(tile)


## Empty when the prefix recipe is incomplete.
func _compute_plated_outputs(tile: Hex) -> Dictionary:
	if get_matched_prefix_recipe(tile).is_empty():
		return {}
	return {
		"flavour": _preview_plated_flavour(tile),
		"additive_mult": _preview_plated_additive_mult(tile),
	}


## Snapshot pay. Prefix cards have already fired when the dish activates.
func _plated_flavour_from_recipe(_recipe: Array[TileCard]) -> int:
	return 0


func _plated_additive_mult_from_recipe(_recipe: Array[TileCard]) -> float:
	return 0.0


## Chip estimate. Uses Hour snapshots after those cards fire, otherwise their board chips.
func _preview_plated_flavour(tile: Hex) -> int:
	var recipe := get_matched_prefix_recipe(tile)
	if recipe.is_empty():
		return 0
	return _plated_flavour_from_recipe(recipe)


func _preview_plated_additive_mult(tile: Hex) -> float:
	var recipe := get_matched_prefix_recipe(tile)
	if recipe.is_empty():
		return 0.0
	return _plated_additive_mult_from_recipe(recipe)


## How many fire-order seats this dish reads immediately before itself.
func get_recipe_prefix_size() -> int:
	return (
		recipe_vegetable_count
		+ recipe_fruit_count
		+ recipe_grain_count
		+ recipe_protein_count
		+ recipe_seasoning_count
		+ recipe_kitchenware_count
	)


## Prefix cards when every required seat is filled and the tag bag matches. Empty on fail.
func get_matched_prefix_recipe(tile: Hex) -> Array[TileCard]:
	var prefix_size := get_recipe_prefix_size()
	if tile == null or tile.map == null or prefix_size <= 0:
		return []
	var hexes := _get_immediately_previous_hexes(tile, prefix_size)
	if hexes.size() != prefix_size:
		return []
	var cards: Array[TileCard] = []
	for hex: Hex in hexes:
		if hex.active_tile_card == null:
			return []
		cards.append(hex.active_tile_card)
	if not _recipe_bag_matches(cards):
		return []
	return cards


func _recipe_bag_matches(cards: Array[TileCard]) -> bool:
	var vegetables := 0
	var fruits := 0
	var grains := 0
	var proteins := 0
	var seasonings := 0
	var kitchenware := 0
	for card: TileCard in cards:
		if card.type == TileCardType.KITCHENWARE:
			kitchenware += 1
			continue
		match card.ingredient_kind:
			IngredientKind.VEGETABLE:
				vegetables += 1
			IngredientKind.FRUIT:
				fruits += 1
			IngredientKind.GRAIN:
				grains += 1
			IngredientKind.PROTEIN:
				proteins += 1
			IngredientKind.SEASONING:
				seasonings += 1
			_:
				return false
	return (
		vegetables == recipe_vegetable_count
		and fruits == recipe_fruit_count
		and grains == recipe_grain_count
		and proteins == recipe_protein_count
		and seasonings == recipe_seasoning_count
		and kitchenware == recipe_kitchenware_count
	)


func _sum_hour_flavour_for_kind(cards: Array[TileCard], kind: IngredientKind) -> int:
	var total := 0
	for card: TileCard in cards:
		if card.ingredient_kind == kind:
			total += card.hour_flavour_produced
	return total


func _sum_hour_additive_mult_for_kind(cards: Array[TileCard], kind: IngredientKind) -> float:
	var total := 0.0
	for card: TileCard in cards:
		if card.ingredient_kind == kind:
			total += card.hour_additive_mult_produced
	return total


## Flavour this prefix card will pay. Hour snapshot after it fires, otherwise its chip.
func _expected_flavour_from_card(card: TileCard, hex: Hex) -> int:
	if card == null:
		return 0
	if card.hour_flavour_produced != 0:
		return card.hour_flavour_produced
	if card.product != Product.SCORE:
		return 0
	return int(round(_chip_amount(card, hex, card._get_production_amount())))


func _expected_additive_mult_from_card(card: TileCard, hex: Hex) -> float:
	if card == null:
		return 0.0
	if not is_zero_approx(card.hour_additive_mult_produced):
		return card.hour_additive_mult_produced
	if card.product != Product.MULTIPLIER:
		return 0.0
	return _chip_amount(card, hex, card._get_production_amount())


func _chip_amount(card: TileCard, hex: Hex, fallback: float) -> float:
	var chip: Dictionary = card.get_board_chip(hex)
	if int(chip.get("mode", BoardChipMode.HIDDEN)) == BoardChipMode.HIDDEN:
		return fallback
	var amount := float(chip.get("amount", 0.0))
	if amount != 0.0:
		return amount
	return fallback


func _sum_expected_flavour_for_kind(tile: Hex, kind: IngredientKind) -> int:
	var total := 0
	for hex: Hex in _get_immediately_previous_hexes(tile, get_recipe_prefix_size()):
		var card := hex.active_tile_card
		if card == null or card.ingredient_kind != kind:
			continue
		total += _expected_flavour_from_card(card, hex)
	return total


func _sum_expected_additive_mult_for_kind(tile: Hex, kind: IngredientKind) -> float:
	var total := 0.0
	for hex: Hex in _get_immediately_previous_hexes(tile, get_recipe_prefix_size()):
		var card := hex.active_tile_card
		if card == null or card.ingredient_kind != kind:
			continue
		total += _expected_additive_mult_from_card(card, hex)
	return total
