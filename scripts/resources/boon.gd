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
	
	# boon = Boon.new()
	# boon.name = "Essence Boost"
	# boon.description = "Start with 1 of x essence"
	# boon.cost = 1
	# boon.effect_type = "essence"
	# boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Common Perk"
	boon.description = "Get a random common perk at run start"
	boon.cost = 1
	boon.effect_type = "perk"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Uncommon Perk"
	boon.description = "Start with a random uncommon perk"
	boon.cost = 2
	boon.effect_type = "perk"
	boons.append(boon)
	
	# boon = Boon.new()
	# boon.name = "Essence Generator"
	# boon.description = "Starting tile generates an additional essence"
	# boon.cost = 1
	# boon.effect_type = "essence_gen"
	# boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Food Supply"
	boon.description = "Start with 25 food"
	boon.cost = 1
	boon.effect_type = "food"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Building Boost"
	boon.description = "Start with x building"
	boon.cost = 3
	boon.effect_type = "building"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Curse Reduction"
	boon.description = "Reduce requirements for first discovered curse by 30%"
	boon.cost = 1
	boon.effect_type = "curse"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Merchant Discount"
	boon.description = "Reduce cost of merchant items by 15%"
	boon.cost = 3
	boon.effect_type = "merchant"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Explorer"
	boon.description = "Start with 2 explored adjacent tiles"
	boon.cost = 2
	boon.effect_type = "exploration"
	boons.append(boon)
	
	boon = Boon.new()
	boon.name = "Rune Boost"
	boon.description = "Start with a random common or uncommon rune"
	boon.cost = 1
	boon.effect_type = "rune"
	boons.append(boon)
	
	return boons 