class_name RecipeTooltip
extends PanelContainer

## A Meal's recipe, shown centred above its card. The look lives in recipe_tooltip.tscn.

const GAP := 10.0

@export var icon_size := 28

@onready var _recipe_label: RichTextLabel = $Rows/Recipe


func show_above(meal: MealCard, element_rect: Rect2) -> void:
	var recipe := meal.get_recipe_tooltip_bbcode(icon_size)
	if recipe.is_empty():
		hide()
		return
	_recipe_label.text = "[center]%s[/center]" % recipe
	# Stay invisible until the label has reflowed and the panel is placed.
	modulate.a = 0.0
	show()
	await get_tree().process_frame
	reset_size()
	var viewport_size := get_viewport_rect().size
	var above := Vector2(
		element_rect.get_center().x - size.x * 0.5,
		element_rect.position.y - size.y - GAP
	)
	position = above.clamp(Vector2.ZERO, (viewport_size - size).max(Vector2.ZERO))
	modulate.a = 1.0
