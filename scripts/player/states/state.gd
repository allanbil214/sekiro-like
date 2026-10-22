class_name State
extends Node
## Base class for player states. Set up by StateMachine.

var player: Player
var machine: StateMachine


func enter(_previous: StringName) -> void:
	pass


func exit(_next: StringName) -> void:
	pass


func physics_update(_delta: float) -> void:
	pass


## Traversal hints (item 16): what this state can do now, as {"action": StringName, "text": String} in the
## order they are shown (an optional "toward": a world direction the player must hold toward, which the Player turns
## into "move_dir" for the hint row). Empty (the default) shows none. Called every frame by the Player while the hints are on.
func get_hints() -> Array[Dictionary]:
	return []
