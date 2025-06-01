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

# called on existing a state
func exit() -> void:
	pass

func on_input(_event: InputEvent) -> void:
	pass
	
func on_gui_input(_event: InputEvent) -> void:
	pass
	
func on_mouse_entered() -> void:
	pass
	
func on_mouse_exited() -> void:
	pass	
