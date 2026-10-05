class_name DodgeState
extends ActionState
## Dodge: a burst of movement with i-frames. Direction follows the movement input;
## with no input it is a backstep. Holding the dodge button after the locked window
## ends turns it into a dash.

@export var backstep_speed_multiplier: float = 0.7


func _on_action_enter(_previous: StringName) -> void:
	var input_dir := player.get_move_input()
	if input_dir.length_squared() > 0.01:
		_move_dir = input_dir.normalized()
		_move_speed_multiplier = 1.0
		player.snap_facing(_move_dir)
	else:
		var back := -player.get_facing_direction()
		back.y = 0.0
		_move_dir = back.normalized()
		_move_speed_multiplier = backstep_speed_multiplier


func _on_action_update(_delta: float) -> void:
	if not action.can_cancel(action_time):
		return
	if player.is_on_floor() and player.input_buffer.consume(&"jump"):
		player.start_jump()
		machine.transition_to(&"Air")
		return
	if player.input_buffer.consume(&"dodge"):
		machine.transition_to(&"Dodge")
		return
	if player.get_move_input().length_squared() > 0.01:
		if Input.is_action_pressed("dodge"):
			machine.transition_to(&"Dash")
		else:
			machine.transition_to(&"Locomotion")
