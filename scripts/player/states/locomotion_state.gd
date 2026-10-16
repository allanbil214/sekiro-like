class_name LocomotionState
extends State
## Normal ground movement. Starts jumps, dodges, attacks, and crouch.


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(StateName.AIR)
		return
	if player.input_buffer.consume(Actions.JUMP):
		player.start_jump()
		machine.transition_to(StateName.AIR)
		return
	if player.input_buffer.consume(Actions.DODGE):
		machine.transition_to(StateName.DODGE)
		return
	if Input.is_action_just_pressed(Actions.INTERACT) and player.try_interact():
		return
	if player.input_buffer.has_pressed(Actions.GUARD):
		machine.transition_to(StateName.GUARD)
		return
	# Sheathed: the attack is the draw slash (iai).
	if player.sheathed and player.input_buffer.has_pressed(Actions.ATTACK):
		var attack := machine.get_state(StateName.ATTACK) as AttackState
		if attack != null and attack.try_start_draw():
			player.input_buffer.consume(Actions.ATTACK)
			return
	if player.has_combo() and player.input_buffer.consume(Actions.ATTACK):
		machine.transition_to(StateName.ATTACK)
		return
	if Input.is_action_just_pressed(Actions.CROUCH):
		machine.transition_to(StateName.CROUCH)
		return
	if Input.is_action_just_pressed(Actions.SHEATHE):
		player.toggle_sheathe()
	if Input.is_action_just_pressed(Actions.REVERSE_BLADE):
		player.toggle_reverse_blade()
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
