class_name CollectionDetailInfoCards
extends HBoxContainer

## Three small parchment cards in a row: First made by, Where, When. Captions are set in the scene.

@onready var _values: Array[Label] = [%WhoValue, %WhereValue, %WhenValue]


func setup(who: String, where: String, when: String) -> void:
	if not is_node_ready():
		await ready
	var texts: Array[String] = [who, where, when]
	for i in _values.size():
		_values[i].text = texts[i] if not texts[i].is_empty() else "Unknown"
