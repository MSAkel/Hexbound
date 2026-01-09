class_name Headquarters
extends Control

var id := "HQ"
var label := "Headquarters"
var description:= "A very nice building"

var temporary_boost: int = 0
# Dictionary storing generated goods with their amounts (e.g., {"gold": 5, "favor": 3})
var generated_goods: Dictionary = {}

@onready var hq_panel: Panel = $HQPanel
@onready var generations: Label = $HQPanel/MarginContainer/VBoxContainer2/VBoxContainer/Generations

var map: HexTileMap
var tile: Hex
var center_coordinates: Vector2i

func _ready() -> void:
	Events.turn_ended.connect(on_turn_ended)
	generated_goods["gold"] = 5
	for good in generated_goods:
		generations.text = "%s: %d" % [good, generated_goods[good]]

func on_turn_ended() -> void:
	# Show floating text for generated goods and add them to inventory
	var tile_pos = map.base_layer.map_to_local(center_coordinates)
	var vertical_offset = 0
	
	for good_id in generated_goods:
		# Convert string good ID to GoodType.Type enum
		if GoodType.ID_TO_TYPE.has(good_id.to_lower()):
			var good_type = GoodType.get_type_from_id(good_id)
			var amount: int = int(generated_goods[good_id])
			GoodsManager.add_good(good_type, amount)
			
			# Show floating text for this good
			var is_gold = good_id.to_lower() == "gold"
			map.create_floating_text(tile_pos + Vector2(0, vertical_offset), "+%s %s" % [amount, good_id.capitalize()], is_gold)
			vertical_offset -= 20  # Offset multiple goods vertically
	
	# Trigger buildings on adjacent tiles
	var surrounding_tiles = map.base_layer.get_surrounding_cells(center_coordinates)
	for coords in surrounding_tiles:
		if map.map_data.has(coords):
			var surrounding_hex = map.map_data[coords]
			if surrounding_hex.active_building != null:
				surrounding_hex.trigger_building_generation()
	
	temporary_boost = 0


func _on_hq_button_pressed() -> void:
	hq_panel.show()

func _on_close_button_pressed() -> void:
	hq_panel.hide()
