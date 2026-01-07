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

#TODO have the goods type linked to enum to avoid unintended values
func _ready() -> void:
	Events.turn_ended.connect(on_turn_ended)
	generated_goods["gold"] = 5
	for good in generated_goods:
		generations.text = "%s: %d" % [good, generated_goods[good]]

func on_turn_ended() -> void:
	for good_id in generated_goods:
		# Convert string good ID to GoodType.Type enum
		var good_type = get_good_type_from_id(good_id)
		if good_type != null:
			var amount: int = int(generated_goods[good_id])
			GoodsManager.add_good(good_type, amount)
	temporary_boost = 0

# Helper function to convert string good ID to GoodType.Type enum
func get_good_type_from_id(good_id: String):
	for type in GoodType.GOOD_IDS:
		if GoodType.GOOD_IDS[type] == good_id:
			return type
	return null  # Return null if good ID not found


func _on_hq_button_pressed() -> void:
	hq_panel.show()

func _on_close_button_pressed() -> void:
	hq_panel.hide()
