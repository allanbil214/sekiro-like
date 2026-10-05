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
