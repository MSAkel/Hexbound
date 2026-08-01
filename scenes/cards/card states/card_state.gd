class_name CardState
extends Node

enum State {BASE, CLICKED, DRAGGING, RELEASED}

signal transition_requested(from: CardState, to: State)

@export var state: State
# reference to the cardui node to allow for adjustments to it
var card_ui: CardUI

# called on entering a new state
func enter() -> void:
	pass

# called on exiting a state; next_state is the state being entered.
func exit(_next_state: State = State.BASE) -> void:
	pass

func on_input(_event: InputEvent) -> void:
	pass
	
func on_gui_input(_event: InputEvent) -> void:
	pass
	
func on_mouse_entered() -> void:
	pass
	
func on_mouse_exited() -> void:
	pass	
