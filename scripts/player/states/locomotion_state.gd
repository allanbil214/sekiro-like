class_name LocomotionState
extends State
## Normal ground movement. Starts jumps and dodges.


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	if player.input_buffer.consume(&"jump"):
		player.start_jump()
		machine.transition_to(&"Air")
		return
	if player.input_buffer.consume(&"dodge"):
		machine.transition_to(&"Dodge")
		return
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
