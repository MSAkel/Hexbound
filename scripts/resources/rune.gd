class_name Rune
extends Resource

enum RuneRarity { 
	COMMON, 
	UNCOMMON, 
	RARE, 
}

enum RuneType {
	GENERATION,
	SUPPORT,
	HYBRID
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var score_value: int = 0
@export_multiline var description: String
@export var selected: bool
@export var rarity: RuneRarity
@export var type: RuneType
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
		# Register before the effect so get_activations_this_turn() includes this rune.
		GameManager.register_rune_activation()
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


# --- Rune context helpers (turn + map queries for effect logic) ---

func get_activations_this_turn() -> int:
	return GameManager.get_runes_activated_this_turn()


func is_on_map_edge(tile: Hex) -> bool:
	return tile.map.is_edge_tile(tile.coordinates)


func get_all_placed_runes(tile: Hex) -> Array[Rune]:
	return tile.map.get_all_placed_runes()


func get_all_hexes_with_runes(tile: Hex) -> Array[Hex]:
	return tile.map.get_all_hexes_with_runes()


func get_unoccupied_adjacent_count(tile: Hex) -> int:
	return tile.map.count_unoccupied_adjacent_hexes(tile.coordinates)


# Pass Rune.RuneType.GENERATION, Rune.RuneType.EFFECT, or omit filter_type for all occupied neighbors.
func get_occupied_adjacent_count(tile: Hex, filter_type: Variant = null) -> int:
	return tile.map.count_occupied_adjacent_hexes(tile.coordinates, filter_type)
