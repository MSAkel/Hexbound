class_name PerkUI
extends Control

@export var perk: Perk : set = set_perk 

@onready var icon: TextureRect = $Frame/Icon

func set_perk(new_perk: Perk) -> void:
	if not is_node_ready():
		await ready
	
	perk = new_perk
	icon.texture = perk.icon

func _on_mouse_entered() -> void:
	pass
	# Display tooltip on hover
