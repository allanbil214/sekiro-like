class_name CrouchState
extends State
## Crouched ground movement (slower, shorter body). Toggle by default, or hold if
## Player.crouch_is_hold is on. Jump and dodge stand you up into the action, but
## only when there is headroom; under a low ceiling those presses are ignored. Attack
## starts the weapon's crouch attack loop (you stay crouched).


func enter(_previous: StringName) -> void:
	player.set_crouched(true)


func exit(next: StringName) -> void:
	# Crouch attacks start from here and keep you crouched.
	if next != &"Attack":
		player.set_crouched(false)


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	if Input.is_action_just_pressed("sheathe"):
		player.toggle_sheathe()
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
	if player.input_buffer.has_pressed(&"guard"):
		if headroom:
			# Guard stands you up (exit() uncrouches); without headroom the press is ignored.
			machine.transition_to(&"Guard")
			return
		player.input_buffer.clear(&"guard")
	if player.weapon != null and player.input_buffer.has_pressed(&"attack"):
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_start_variant(player.weapon.crouch_attack):
			player.input_buffer.consume(&"attack")
			return
	if headroom:
		var wants_stand := not Input.is_action_pressed("crouch") if player.crouch_is_hold \
				else Input.is_action_just_pressed("crouch")
		if wants_stand:
			machine.transition_to(&"Locomotion")
			return
	player.apply_horizontal_movement(delta, player.crouch_speed, player.crouch_decel)
	player.face_input(delta)
