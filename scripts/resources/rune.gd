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
}
@export var activation_cost_text: String
@export var boosted_generation_amount: int = 0
var is_active: bool = true

func activate_rune(tile: Hex) -> void:
	if not is_active:
		return
	
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

func get_gold_cost() -> int:
	return activation_cost.get("gold", 0)

func can_activate() -> bool:
	return GameManager.get_gold() >= get_gold_cost()

func deduct_activation_cost() -> void:
	GameManager.remove_gold(get_gold_cost())
