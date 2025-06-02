class_name CardUI
extends Control

# signal for reparenting the card
signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://themes/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://themes/card_hover_stylebox.tres")
const DRAG_STYLEBOX := preload("res://themes/card_drag_stylebox.tres")

@onready var card_name: Label = $VBoxContainer/CardName
@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var card_description: Label = $VBoxContainer/CardDescription

@onready var drop_point_area: Area2D = $DropPointArea
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []
@onready var starting_hand_position := self.get_index()

enum CardType {
	BUILDING,
	RUNE,
}

var card = null
var card_type: CardType

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

func set_card(data) -> void:
	if not is_node_ready():
		await ready
	
	card = data
	card_name.text = data.name
	icon.texture = data.icon
	card_description.text = data.description
	
	# Determine card type based on the data
	if data is Building:
		card_type = CardType.BUILDING
	elif data is Rune:
		card_type = CardType.RUNE
	else:
		push_error("Unknown card type for data: ", data)

func get_card_type() -> CardType:
	return card_type

func _on_drop_point_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_area_exited(area: Area2D) -> void:
	targets.erase(area)
