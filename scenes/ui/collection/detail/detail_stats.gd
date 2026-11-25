class_name CollectionDetailStats
extends PanelContainer

## "Your stats" strip: a row of numbers with a caption under each. Never-seen entries show zeros.

const ITEM_SCENE := preload("res://scenes/ui/collection/detail/detail_stat_item.tscn")

@onready var _items: HBoxContainer = %Items


## items: [caption, value text] pairs, left to right.
func setup(items: Array) -> void:
	if not is_node_ready():
		await ready
	for child in _items.get_children():
		child.queue_free()
	for item: Variant in items:
		var pair := item as Array
		var node := ITEM_SCENE.instantiate() as Control
		(node.get_node("Value") as Label).text = String(pair[1])
		(node.get_node("Caption") as Label).text = String(pair[0]).to_upper()
		_items.add_child(node)
