# state_machine.gd
# Generic layered state machine.
# Attach as child node, assign owner_node in code.
extends Node

signal state_changed(new_state_name: String)

var current_state: State = null
var states: Dictionary = {}  # name → State node
var owner_node: Node = null   # the entity this FSM belongs to

func _ready() -> void:
	# Collect all State children
	for child in get_children():
		if child is State:
			states[child.name] = child
			child.state_machine = self

func init(start_state_name: String, p_owner: Node) -> void:
	owner_node = p_owner
	if states.has(start_state_name):
		current_state = states[start_state_name]
		current_state.enter({})

func transition_to(state_name: String, msg: Dictionary = {}) -> void:
	if not states.has(state_name):
		push_warning("StateMachine: unknown state " + state_name)
		return
	if current_state:
		current_state.exit()
	current_state = states[state_name]
	current_state.enter(msg)
	state_changed.emit(state_name)

func get_current_state_name() -> String:
	return current_state.name if current_state else ""

func _process(delta: float) -> void:
	if current_state:
		current_state.update(delta)

func _physics_process(delta: float) -> void:
	if current_state:
		current_state.physics_update(delta)

func _unhandled_input(event: InputEvent) -> void:
	if current_state:
		current_state.handle_input(event)


# ---------------------------------------------------------------------------
# Base State class — extend this for each concrete state
# ---------------------------------------------------------------------------
class State extends Node:
	var state_machine: Node = null  # ref to StateMachine

	func enter(_msg: Dictionary) -> void:
		pass

	func exit() -> void:
		pass

	func update(_delta: float) -> void:
		pass

	func physics_update(_delta: float) -> void:
		pass

	func handle_input(_event: InputEvent) -> void:
		pass
