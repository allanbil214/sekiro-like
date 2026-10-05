class_name AirState
extends State
## In the air: gravity, air control, coyote jump, and landing.


func physics_update(delta: float) -> void:
	player.coyote_timer = maxf(player.coyote_timer - delta, 0.0)
	player.apply_gravity(delta)
	if player.try_ledge_grab():
		machine.transition_to(&"LedgeClimb")
		return
	if player.coyote_timer > 0.0 and player.input_buffer.consume(&"jump"):
		player.start_jump()
	elif player.coyote_timer <= 0.0 and player.try_air_jump():
		machine.transition_to(&"WallJump")
		return
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
		machine.transition_to(&"Locomotion")
