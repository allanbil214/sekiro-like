class_name LocomotionState
extends State
## Normal ground movement. Starts jumps, dodges, and crouch.


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
	if Input.is_action_just_pressed("crouch"):
		machine.transition_to(&"Crouch")
		return
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
