class_name KitchenwarePrep
extends RefCounted

## Kitchenware statuses: how a Kitchenware prepares the Ingredients near it so Meals can use them.
##
## Retriggered and Garnished happen when the Kitchenware triggers (Chef's Knife, Skillet, Deep Fryer;
## Whisk, Kitchen Torch). The three below depend only on where cards sit, so HexBoardQuery rebuilds
## them whenever a seat changes and recipes see them before the Hour starts:
## - Seasoned (Mortar & Pestle): the next Ingredient on its Station also counts as a Seasoning.
## - Blended (Blender): the next 2 Ingredients on its Station each also count as the other's kinds.
## - Passed (Cutting Board): the next Ingredient on its Station also counts on the Station below,
##   for that Station's Meals (recipes and their effects), but its Flavour is not paid there.
## None of them count toward Station setups, which read printed tags only.

const STATUS_SEASONED := &"seasoned"
const STATUS_BLENDED := &"blended"
const STATUS_PASSED := &"passed"


## Recipe kinds printed on a card (Vegetable, Fruit, ...), leaving out Dish and Beverage tags.
static func printed_recipe_kinds(card: TileCard) -> Array[StringName]:
	var kinds: Array[StringName] = []
	if card == null:
		return kinds
	for tag: StringName in card.ingredient_tags:
		if tag in TileCard.RECIPE_INGREDIENT_TAGS and tag not in kinds:
			kinds.append(tag)
	return kinds
