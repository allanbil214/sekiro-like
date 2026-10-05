class_name StateMachine
extends Node
## Holds the player's states (its child nodes) and switches between them.
## The Player calls physics_update() so the update order stays predictable.

@export var initial_state: State

var current: State

var _states: Dictionary = {}


func setup(player: Player) -> void:
	for child in get_children():
		var state := child as State
		if state == null:
			continue
		state.player = player
		state.machine = self
		_states[state.name] = state


func start() -> void:
	assert(initial_state != null, "StateMachine: set Initial State in the Inspector.")
	current = initial_state
	current.enter(&"")


func physics_update(delta: float) -> void:
	if current != null:
		current.physics_update(delta)


## Switch state. Callers should return right after calling this.
func transition_to(state_name: StringName) -> void:
	var next: State = _states.get(state_name)
	if next == null:
		push_error("StateMachine: no state named '%s'" % str(state_name))
		return
	var previous: StringName = &""
	if current != null:
		previous = current.name
		current.exit(next.name)
	current = next
	current.enter(previous)


func get_current_name() -> StringName:
	if current == null:
		return &""
	return current.name
