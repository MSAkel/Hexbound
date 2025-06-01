class_name Rune
extends Resource

enum RuneRarity { 
	COMMON, 
	UNCOMMON, 
	RARE, 
	LEGENDARY 
}

@export var id: String
@export var name: String
@export var icon: Texture2D
@export_multiline var description: String
@export var selected: bool
@export var rarity: RuneRarity

# Essence costs for activation
# @export var fire_essence_cost: int = 0
# @export var nature_essence_cost: int = 0
# @export var frost_essence_cost: int = 0
# @export var storm_essence_cost: int = 0

# func can_activate() -> bool:
# 	return (
# 		GameManager.fire_essence >= fire_essence_cost and
# 		GameManager.nature_essence >= nature_essence_cost and
# 		GameManager.frost_essence >= frost_essence_cost and
# 		GameManager.storm_essence >= storm_essence_cost
# 	)

# func get_essence_requirements_text() -> String:
# 	var requirements = []
# 	if fire_essence_cost > 0:
# 		requirements.append(str(fire_essence_cost) + " Fire")
# 	if nature_essence_cost > 0:
# 		requirements.append(str(nature_essence_cost) + " Nature")
# 	if frost_essence_cost > 0:
# 		requirements.append(str(frost_essence_cost) + " Frost")
# 	if storm_essence_cost > 0:
# 		requirements.append(str(storm_essence_cost) + " Storm")
	
# 	if requirements.is_empty():
# 		return "No essence required"
# 	return "Requires: " + ", ".join(requirements)
