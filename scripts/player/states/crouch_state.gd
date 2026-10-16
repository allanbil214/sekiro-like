class_name CrouchState
extends State
## Crouched ground movement (slower, shorter body). Toggle by default, or hold if
## Player.crouch_is_hold is on. Jump and dodge stand you up into the action, but
## only when there is headroom; under a low ceiling those presses are ignored. Attack
## starts the weapon's crouch attack loop (you stay crouched).


func enter(previous: StringName) -> void:
	player.set_crouched(true)
	if previous == StateName.LOCOMOTION:
		Sfx.play(player.get_tree(), Sfx.Id.CROUCH)


func exit(next: StringName) -> void:
	# Crouch attacks start from here and keep you crouched; so does the wall hug (item 9).
	if next != StateName.ATTACK and next != StateName.WALL_HUG:
		player.set_crouched(false)


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(StateName.AIR)
		return
	if Input.is_action_just_pressed(Actions.SHEATHE):
		player.toggle_sheathe()
	if Input.is_action_just_pressed(Actions.REVERSE_BLADE):
		player.toggle_reverse_blade()
	if Input.is_action_just_pressed(Actions.INTERACT) and player.try_interact():
		return
	var headroom := player.can_stand()
	if player.input_buffer.has_pressed(Actions.JUMP):
		if headroom:
			player.input_buffer.consume(Actions.JUMP)
			player.start_jump()
			machine.transition_to(StateName.AIR)
			return
		player.input_buffer.clear(Actions.JUMP)
	if player.input_buffer.has_pressed(Actions.DODGE):
		if headroom:
			player.input_buffer.consume(Actions.DODGE)
			machine.transition_to(StateName.DODGE)
			return
		player.input_buffer.clear(Actions.DODGE)
	if player.input_buffer.has_pressed(Actions.GUARD):
		if headroom:
			# Guard stands you up (exit() uncrouches); without headroom the press is ignored.
			machine.transition_to(StateName.GUARD)
			return
		player.input_buffer.clear(Actions.GUARD)
	if player.weapon != null and player.input_buffer.has_pressed(Actions.ATTACK):
		var attack := machine.get_state(StateName.ATTACK) as AttackState
		if attack != null and attack.try_start_variant(player.weapon.crouch_attack):
			player.input_buffer.consume(Actions.ATTACK)
			return
	if headroom:
		var wants_stand := not Input.is_action_pressed(Actions.CROUCH) if player.crouch_is_hold \
				else Input.is_action_just_pressed(Actions.CROUCH)
		if wants_stand:
			machine.transition_to(StateName.LOCOMOTION)
			return
	player.apply_horizontal_movement(delta, player.crouch_speed, player.crouch_decel)
	player.face_input(delta)
