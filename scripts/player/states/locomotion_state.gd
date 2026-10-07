class_name LocomotionState
extends State
## Normal ground movement. Starts jumps, dodges, attacks, and crouch.


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
	if player.input_buffer.has_pressed(&"guard"):
		machine.transition_to(&"Guard")
		return
	# Sheathed: the attack is the draw slash (iai).
	if player.sheathed and player.input_buffer.has_pressed(&"attack"):
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_start_draw():
			player.input_buffer.consume(&"attack")
			return
	if player.has_combo() and player.input_buffer.consume(&"attack"):
		machine.transition_to(&"Attack")
		return
	if Input.is_action_just_pressed("crouch"):
		machine.transition_to(&"Crouch")
		return
	if Input.is_action_just_pressed("sheathe"):
		player.toggle_sheathe()
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
