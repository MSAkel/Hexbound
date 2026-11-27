class_name CollectionDetailOutfitSection
extends VBoxContainer

## Chef page: the alternate outfit. Locked, the chef's portrait is a flat silhouette (tinted, alpha
## kept) with its chef level; unlocked, the recoloured portrait and the outfit's name.

## Multiplies the portrait to a flat black shape. Alpha stays.
@export var silhouette_color := Color(0, 0, 0, 1)

@onready var _portrait: TextureRect = %Portrait
@onready var _name: Label = %Name
@onready var _requirement: HBoxContainer = %Requirement
@onready var _level: Label = %Level


## outfit: {"level", "name", "portrait", "tint"} from ChefProgression.
func setup(chef: ChefDefinition, outfit: Dictionary, chef_level: int) -> void:
	if not is_node_ready():
		await ready
	var required := int(outfit.get("level", ChefProgression.MAX_LEVEL))
	# An outfit with no name has no content yet and stays locked.
	var unlocked := chef_level >= required and not String(outfit.get("name", "")).is_empty()
	_portrait.texture = chef.icon
	_requirement.visible = not unlocked
	_name.visible = unlocked
	if not unlocked:
		_portrait.self_modulate = silhouette_color
		_level.text = "Chef level %d" % required
		return
	_name.text = String(outfit.get("name", ""))
	var portrait_path := String(outfit.get("portrait", ""))
	if not portrait_path.is_empty() and ResourceLoader.exists(portrait_path):
		_portrait.texture = load(portrait_path) as Texture2D
	elif not String(outfit.get("tint", "")).is_empty():
		# Until the outfit has its own portrait, the base portrait is recoloured.
		_portrait.self_modulate = Color.from_string(String(outfit["tint"]), Color.WHITE)
