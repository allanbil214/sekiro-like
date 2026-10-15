class_name AirState
extends State
## In the air: gravity, air control, coyote jump, and landing.


func physics_update(delta: float) -> void:
	player.coyote_timer = maxf(player.coyote_timer - delta, 0.0)
	player.apply_gravity(delta)
	if player.ledge_sensor.try_ledge_grab():
		machine.transition_to(player.ledge_sensor.ledge_grab_state())
		return
	if player.coyote_timer > 0.0 and player.input_buffer.consume(Actions.JUMP):
		player.start_jump()
	elif player.coyote_timer <= 0.0 and player.try_air_jump():
		machine.transition_to(StateName.WALL_JUMP)
		return
	# Jump guard (and jump deflect): the same Guard state, with gravity.
	if player.input_buffer.has_pressed(Actions.GUARD):
		machine.transition_to(StateName.GUARD)
		return
	# Death from above (item 7c): an attack press over a stealth target plunges onto it.
	if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK, player.aerial_kill_buffer_time):
		var aerial_target := player.find_aerial_target()
		if aerial_target != null:
			player.begin_aerial_kill(aerial_target)
			return
	# Attack in the air starts the air tap loop. Close to the ground the press stays buffered,
	# so landing turns it into a ground attack instead.
	if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK) \
			and not player.is_near_ground():
		var air_attack := machine.get_state(StateName.AIR_ATTACK) as AirAttackState
		if air_attack != null and air_attack.start():
			player.input_buffer.consume(Actions.ATTACK)
			return
	player.apply_air_steering(delta)
	player.face_input(delta)
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
		machine.transition_to(StateName.LOCOMOTION)
