class_name CardStateMachine
extends Node

@export var initial_state: CardState

var current_state: CardState
var states := {}

func init(card: CardUI) -> void:
	# itirate through all the children of the state machine
	for child in get_children():
		# Check if current child is a card state
		if child is CardState:
			# add the child to the dictionary of all the states 
			states[child.state] = child
			# connect transition_requested signal to our function where the transition will be handled
			child.transition_requested.connect(_on_transition_requested)
			# Pass the card UI reference to the state itself
			child.card_ui = card
	
	# if there is an inital state then enter that state	and set it as the current state
	if initial_state:
		initial_state.enter()
		current_state = initial_state
		
func on_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_input(event)

func on_gui_input(event: InputEvent) -> void:
	if current_state:
		current_state.on_gui_input(event)
		
func on_mouse_entered() -> void:
	if current_state:
		current_state.on_mouse_entered()

func on_mouse_exited() -> void:
	if current_state:
		current_state.on_mouse_exited()
		
func _on_transition_requested(from: CardState, to: CardState.State) -> void:
	if from != current_state:
		return
	
	var new_state: CardState = states[to]
	if not new_state:
		return
	
	if current_state:
		current_state.exit()
		
	new_state.enter()
	current_state = new_state
