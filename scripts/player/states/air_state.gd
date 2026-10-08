class_name AirState
extends State
## In the air: gravity, air control, coyote jump, and landing.


func physics_update(delta: float) -> void:
	player.coyote_timer = maxf(player.coyote_timer - delta, 0.0)
	player.apply_gravity(delta)
	if player.try_ledge_grab():
		machine.transition_to(player.ledge_grab_state())
		return
	if player.coyote_timer > 0.0 and player.input_buffer.consume(&"jump"):
		player.start_jump()
	elif player.coyote_timer <= 0.0 and player.try_air_jump():
		machine.transition_to(&"WallJump")
		return
	# Jump guard (and jump deflect): the same Guard state, with gravity.
	if player.input_buffer.has_pressed(&"guard"):
		machine.transition_to(&"Guard")
		return
	# Attack in the air starts the air tap loop. Close to the ground the press stays buffered,
	# so landing turns it into a ground attack instead.
	if player.weapon != null and player.input_buffer.has_pressed(&"attack") \
			and not player.is_near_ground():
		var air_attack := machine.get_node_or_null("AirAttack") as AirAttackState
		if air_attack != null and air_attack.start():
			player.input_buffer.consume(&"attack")
			return
	player.apply_air_steering(delta)
	player.face_input(delta)
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
		machine.transition_to(&"Locomotion")
