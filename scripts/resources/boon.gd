extends Resource
class_name Boon

@export var name: String
@export var description: String
@export var cost: int
@export var effect_type: String

static func get_all_boons() -> Array[Boon]:
	var boons: Array[Boon] = []
	
	# Create boons
	var boon = Boon.new()
	boon.name = "Gold Boost"
	boon.description = "Start with 15 gold"
	boon.cost = 1
	boon.effect_type = "gold"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Head Start"
	boon.description = "Start with 2 progress"
	boon.cost = 1
	boon.effect_type = "score"
	boons.append(boon)

	boon = Boon.new()
	boon.name = "Merchant Discount"
	boon.description = "Reduce cost of merchant items by 15%"
	boon.cost = 3
	boon.effect_type = "merchant"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Rune Boost"
	boon.description = "Start with a random common or uncommon rune"
	boon.cost = 1
	boon.effect_type = "rune"
	boons.append(boon)
	
	return boons 