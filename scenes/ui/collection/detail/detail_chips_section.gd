class_name CollectionDetailChipsSection
extends VBoxContainer

## A heading over a wrapping row of pills (Traditional ingredients, Signature Meals).

const CHIP_SCENE := preload("res://scenes/ui/collection/detail/detail_chip.tscn")

@onready var _heading: Label = $Heading
@onready var _chips: HFlowContainer = $Chips


func setup(heading: String, texts: Array[String]) -> void:
	if not is_node_ready():
		await ready
	_heading.text = heading
	for child in _chips.get_children():
		child.queue_free()
	for text: String in texts:
		var chip := CHIP_SCENE.instantiate() as PanelContainer
		(chip.get_node("Label") as Label).text = text
		_chips.add_child(chip)
