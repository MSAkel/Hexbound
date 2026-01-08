class_name Building
extends Resource

enum BuildingType { 
	## Generates minerals on trigger
	MINE, 
	## Generates insights on trigger
	LIBRARY,
	## Generates food on trigger
	FARM,
	## Generates wood on trigger
	LUMBER_CAMP,
	## Generates stone on trigger
	QUARRY,
	## Generates gold on trigger
	MINTING_FACILITY,
	## Reveals adjacent tiles
	OUTPOST,
	## Converts 3 gold into 1 insight
	PAPER_MILL,
	## Converts 3 gold into 1 mineral
	MINERAL_EXTRACTOR,
	## Passivly generates 0.1 influence per turn, consumes 3 food per turn.
	HOUSING_UNIT,
	## Randomly generates at least 1 gold/mineral/stone with a chance to generate an additiona 1-2 resource
	EXCAVATION_SITE,
	## Generates 1 of each resource on trigger
	GUILD_HALL,
	## Adds 1 favor on placement and generates 0.1 influence on trigger
	ROYAL_GARDEN,
	## 25% chance to trigger the glyph on this tile again
	BEACON,
	## Passively generates 0.2 influence. Generates 4 gold on trigger
	TEMPLE,
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export var type: BuildingType
@export var generated_goods: Dictionary = {
	"gold": 0,
	"food": 0,
	"wood": 0,
	"stone": 0,
	"insight": 0,
	"minerals": 0,
	"favor": 0,
}
## If true, the building will be activated once and not triggered by runes
@export var passive: bool = false 
@export_multiline var description: String
@export_multiline var tooltip: String

var temporary_boost: int = 0


# default implementation: generate all goods from generated_goods dictionary
# Currently only gets fired by runes
func trigger_building() -> void:
	# if a building is passive, it will be activated once and not triggered by runes
	if passive:
		activate_passive()
		return
	
	for good in generated_goods:
		var amount = int(generated_goods[good])
		var final_amount = amount
		if final_amount > 0:
			var good_type = get_good_type_from_id(good)
			if good_type != null:
				GoodsManager.add_good(good_type, final_amount)


func get_good_type_from_id(good: String):
	for type in GoodType.GOOD_IDS:
		if GoodType.GOOD_IDS[type] == good:
			return type
	return null

func get_tooltip() -> String:
	return tooltip


func reset_temporary_boost() -> void:
	temporary_boost = 0

func activate_passive() -> void:
	pass
