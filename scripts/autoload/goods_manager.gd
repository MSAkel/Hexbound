extends Node


signal good_amount_changed(good: Good, new_amount: int)

var amounts: Dictionary = {}
var goods_by_type: Dictionary = {}

func _ready() -> void:
	# Initialize goods by type
	for type in GoodType.Type.values():
		var good = load("res://resources/goods/" + GoodType.get_good_id(type) + ".tres")
		if good:
			goods_by_type[type] = good
			amounts[good] = 0

func get_good_amount(type: GoodType.Type) -> int:
	var good = goods_by_type.get(type)
	if good:
		return amounts.get(good, 0)
	return 0


func add_good(good: Good, amount: int) -> void:
	if amounts.has(good):
		amounts[good] += amount
		good_amount_changed.emit(good, amounts[good])
	else:
		amounts[good] = amount
		good_amount_changed.emit(good, amounts[good])


func remove_good(type: GoodType.Type, amount: int) -> void:
	var good = goods_by_type.get(type)
	if good:
		amounts[good] -= amount
		good_amount_changed.emit(good, amounts[good])
	else:
		amounts[good] = 0
		good_amount_changed.emit(good, amounts[good])
