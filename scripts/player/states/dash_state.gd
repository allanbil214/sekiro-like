class_name DashState
extends State
## Fast run while the dodge button stays held. Ends on release, no movement input,
## leaving the ground, or jumping.


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	if player.input_buffer.consume(&"jump"):
		player.start_jump()
		machine.transition_to(&"Air")
		return
	var has_input := player.get_move_input().length_squared() > 0.01
	if not Input.is_action_pressed("dodge") or not has_input:
		machine.transition_to(&"Locomotion")
		return
	player.apply_horizontal_movement(delta, player.dash_speed)
	player.face_input(delta)
