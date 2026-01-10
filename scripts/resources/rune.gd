class_name Rune
extends Resource

enum RuneRarity { 
	COMMON, 
	UNCOMMON, 
	RARE, 
	LEGENDARY 
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var selected: bool
@export var rarity: RuneRarity
@export var activation_cost: Dictionary = {
	"gold": 0,
	"insight": 0,
	"minerals": 0,
}
@export var activation_cost_text: String
@export var boosted_generation_amount: int = 0

func activate_rune(tile: Hex) -> void:
	# if tile.active_building.passive:
	# 	return
	if can_activate():
		deduct_activation_cost()
		_on_activate_rune(tile)
	else:
		var floating_text = preload("res://scenes/animations/floating_text.tscn").instantiate()
		floating_text.set_text("Insufficient resources", false)
		tile.map.add_child(floating_text)
		floating_text.position = tile.map.base_layer.map_to_local(tile.coordinates) + Vector2(-120, -60)


func _on_activate_rune(tile: Hex) -> void:
	pass

func can_activate() -> bool:
	if GoodsManager.get_good_amount(GoodType.Type.GOLD) >= activation_cost["gold"] and GoodsManager.get_good_amount(GoodType.Type.INSIGHT) >= activation_cost["insight"] and GoodsManager.get_good_amount(GoodType.Type.MINERALS) >= activation_cost["minerals"]:
		return true

	return false

func deduct_activation_cost() -> void:
	GoodsManager.remove_good(GoodType.Type.GOLD, activation_cost["gold"])
	GoodsManager.remove_good(GoodType.Type.INSIGHT, activation_cost["insight"])
	GoodsManager.remove_good(GoodType.Type.MINERALS, activation_cost["minerals"])
