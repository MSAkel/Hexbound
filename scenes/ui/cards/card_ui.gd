class_name CardUI
extends Control

# signal for reparenting the card
signal reparent_requested(which_card_ui: CardUI)

const BASE_STYLEBOX := preload("res://themes/card_base_stylebox.tres")
const HOVER_STYLEBOX := preload("res://themes/card_hover_stylebox.tres")
const DRAG_STYLEBOX := preload("res://themes/card_drag_stylebox.tres")

#@onready var card_name: Label = $VBoxContainer/CardName
@onready var card_name: Label = $VBoxContainer/NameContainer/CardName
#@onready var icon: TextureRect = $VBoxContainer/Icon
@onready var icon: TextureRect = $VBoxContainer/IconContainer/Icon
@onready var card_description: Label = $VBoxContainer/CardDescription
#@onready var activation_cost: Label = $VBoxContainer/ActivationCost
#@onready var activation_cost: Label = $VBoxContainer/ActivationCost
@onready var resource_cost_container: HBoxContainer = $VBoxContainer/ResourceCostContainer
@onready var card_type_label: Label = $VBoxContainer/IconContainer/CardTypeLabel

@onready var drop_point_area: Area2D = $DropPointArea
@onready var card_state_machine: CardStateMachine = $CardStateMachine as CardStateMachine
@onready var targets: Array[Node] = []
@onready var starting_hand_position := self.get_index()

@onready var panel: Panel = $Panel
# Scene-authored border glow; toggled when the card enters/exits the clicked placement state.
@onready var selection_glow: Panel = $SelectionGlow

enum CardType {
	RUNE,
}

var card = null
var card_type: CardType

# Hand-slot elevation (kept on CardUI so layout reflows stay in sync).
const HOVER_ELEVATION_OFFSET := -40.0
const HOVER_ANIMATION_DURATION := 0.2
var _hand_slot_position := Vector2.ZERO
var _is_hover_elevated := false
var _elevation_tween: Tween

func _ready() -> void:
	_hand_slot_position = position
	card_state_machine.init(self)


func _notification(what: int) -> void:
	# HBoxContainer relayout resets position; re-apply the hover offset when needed.
	if what == NOTIFICATION_MOVED_IN_PARENT:
		_on_hand_slot_moved()


func _on_hand_slot_moved() -> void:
	if _elevation_tween and _elevation_tween.is_valid():
		_elevation_tween.kill()
		_elevation_tween = null
	
	_hand_slot_position = position
	if _is_hover_elevated:
		position = _hand_slot_position + Vector2(0, HOVER_ELEVATION_OFFSET)


func capture_hand_slot() -> void:
	if _is_hover_elevated:
		_hand_slot_position = position - Vector2(0, HOVER_ELEVATION_OFFSET)
	else:
		_hand_slot_position = position


func is_hover_elevated() -> bool:
	return _is_hover_elevated


func set_hover_elevated(elevated: bool, animate: bool = true) -> void:
	if _elevation_tween:
		_elevation_tween.kill()
		_elevation_tween = null
	
	# Only read position when settled at the layout slot; never from a mid-tween pose.
	if not _is_hover_elevated:
		_hand_slot_position = position
	
	_is_hover_elevated = elevated
	var target_position := _hand_slot_position
	if elevated:
		target_position += Vector2(0, HOVER_ELEVATION_OFFSET)
	
	if not animate or position.distance_to(target_position) < 0.5:
		position = target_position
		if not elevated:
			_hand_slot_position = position
		return
	
	_elevation_tween = create_tween()
	_elevation_tween.set_ease(Tween.EASE_OUT if elevated else Tween.EASE_IN)
	_elevation_tween.set_trans(Tween.TRANS_QUART)
	_elevation_tween.tween_property(self, "position", target_position, HOVER_ANIMATION_DURATION)
	_elevation_tween.finished.connect(func() -> void:
		_elevation_tween = null
		if not _is_hover_elevated:
			_hand_slot_position = position
	)
	
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
	
	if data is Rune:
		card_type = CardType.RUNE
		card_type_label.text = "Rune"
		panel.modulate = Color.GREEN
	else:
		push_error("Unknown card type for data: ", data)

func get_card_type() -> CardType:
	return card_type


func is_mouse_over() -> bool:
	return get_global_rect().has_point(get_global_mouse_position())


func show_selection_glow() -> void:
	selection_glow.visible = true
	# Warm highlight so the selected card reads clearly above the rest of the hand.
	panel.modulate = Color(1.15, 1.1, 0.75, 1.0)


func hide_selection_glow() -> void:
	selection_glow.visible = false
	if card is Rune:
		panel.modulate = Color.GREEN
	else:
		panel.modulate = Color.WHITE

func _on_drop_point_area_entered(area: Area2D) -> void:
	if not targets.has(area):
		targets.append(area)


func _on_drop_point_area_exited(area: Area2D) -> void:
	targets.erase(area)
