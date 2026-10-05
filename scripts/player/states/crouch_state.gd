class_name CrouchState
extends State
## Crouched ground movement (slower, shorter body). Toggle by default, or hold if
## Player.crouch_is_hold is on. Jump and dodge stand you up into the action, but
## only when there is headroom; under a low ceiling those presses are ignored.


func enter(_previous: StringName) -> void:
	player.set_crouched(true)


func exit(_next: StringName) -> void:
	player.set_crouched(false)


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	var headroom := player.can_stand()
	if player.input_buffer.has_pressed(&"jump"):
		if headroom:
			player.input_buffer.consume(&"jump")
			player.start_jump()
			machine.transition_to(&"Air")
			return
		player.input_buffer.clear(&"jump")
	if player.input_buffer.has_pressed(&"dodge"):
		if headroom:
			player.input_buffer.consume(&"dodge")
			machine.transition_to(&"Dodge")
			return
		player.input_buffer.clear(&"dodge")
	if headroom:
		var wants_stand := not Input.is_action_pressed("crouch") if player.crouch_is_hold \
				else Input.is_action_just_pressed("crouch")
		if wants_stand:
			machine.transition_to(&"Locomotion")
			return
	player.apply_horizontal_movement(delta, player.crouch_speed, player.crouch_decel)
	player.face_input(delta)
