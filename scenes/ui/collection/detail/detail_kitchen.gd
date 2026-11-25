class_name CollectionDetailKitchen
extends PanelContainer

## Dark "In the kitchen" panel: the card's real effect text, and for Meals the recipe as slots.
## The text always comes from the card, so it never goes stale when numbers change.

const SLOT_SCENE := preload("res://scenes/ui/collection/detail/recipe_slot.tscn")

@onready var _heading: Label = %Heading
@onready var _effect: RichTextLabel = %Effect
@onready var _recipe_caption: Label = %RecipeCaption
@onready var _recipe: HFlowContainer = %Recipe
@onready var _no_recipe: Label = %NoRecipe


## slots: {"icon": Texture2D, "text": String, "any": bool} each. show_recipe false hides the
## recipe part (cards that are not Meals). True with no slots shows the no-recipe line.
func setup(heading: String, effect_bbcode: String, show_recipe: bool, slots: Array[Dictionary] = []) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading
	_effect.text = effect_bbcode
	_effect.visible = not effect_bbcode.is_empty()
	for child in _recipe.get_children():
		child.queue_free()
	_recipe_caption.visible = show_recipe
	_recipe.visible = show_recipe and not slots.is_empty()
	_no_recipe.visible = show_recipe and slots.is_empty()
	for slot: Dictionary in slots:
		var node := SLOT_SCENE.instantiate() as CollectionRecipeSlot
		_recipe.add_child(node)
		node.setup(slot.get("icon") as Texture2D, String(slot.get("text", "")), bool(slot.get("any", false)))
