class_name CardUI
extends Control

# signal for reparenting the card
signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://themes/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://themes/card_hover_stylebox.tres")
const DRAG_STYLEBOX := preload("res://themes/card_drag_stylebox.tres")

@export var card: Card : set = _set_card

#@onready var color: ColorRect = $Color
#@onready var state: Label = $State
@onready var panel: Panel = $Panel
@onready var label: Label = $Label
@onready var icon: TextureRect = $Icon
@onready var drop_point_area: Area2D = $DropPointArea
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []

func _ready() -> void:
	card_state_machine.init(self)
	
func _input(event: InputEvent) -> void:
	card_state_machine.on_input(event)

func _on_gui_input(event: InputEvent) -> void:
	card_state_machine.on_gui_input(event)

func _on_mouse_entered() -> void:
	card_state_machine.on_mouse_entered()

func _on_mouse_exited() -> void:
	card_state_machine.on_mouse_exited()

func _set_card(data: Card) -> void:
	if not is_node_ready():
		await ready
	
	card = data
	#label.text = str(card.label)
	icon.texture = card.icon

func _on_drop_point_area_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_area_area_exited(area: Area2D) -> void:
	targets.erase(area)
