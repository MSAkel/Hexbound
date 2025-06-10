class_name PerkManager
extends MarginContainer

# used to indicate what type of perk was activated
signal perks_activated(type: Perk.Type)

# amount of time interval in seconds between relic activation
# This can later on be used to allow for slower or faster intervals adjustment
const PERK_ACTIVATION_INTERVAL := 1.0
const PERK_UI = preload("res://scenes/ui/perks/perk_ui.tscn")

@onready var perks_grid: GridContainer = $PerksGrid

func activate_perk_by_type(type: Perk.Type) -> void:
	# Passive perks will be handled the moment they are added, so there is no need to do any further checks
	if type == Perk.Type.PASSIVE:
		return
	
	# Filter perks to only get the ones which match the type being passed as an arg
#     var perk_queue: Array[PerkUI] = _get_perk_ui_nodes().filter(
#         func(perk_ui: PerkUI): 
#             return perk_ui.perk.type == type
#     )

#     if perk_queue.is_empty():
#         perks_activated.emit(type)
#         return
	
#     var tween := create_tween()
#     for perk_ui: PerkUI in perk_queue:
#         tween.tween_callback(perk_ui.perk.activate_perk.bind(perk_ui))
#         tween.tween_interval(PERK_ACTIVATION_INTERVAL)
	
#     tween.finished.connect(func(): perks_activated.emit(type))

# func add_perks(perks_array: Array[Perk]) -> void:
#     for perk: Perk in perks_array:
#         add_perk(perk)
