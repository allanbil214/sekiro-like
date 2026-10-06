class_name DashState
extends State
## Fast run while the dodge button stays held. Ends on release, no movement input,
## leaving the ground, or jumping. Pressing crouch starts a slide, and pressing attack
## starts the weapon's dash attack.


func physics_update(delta: float) -> void:
	if not player.is_on_floor():
		player.coyote_timer = player.coyote_time
		machine.transition_to(&"Air")
		return
	if player.input_buffer.consume(&"jump"):
		player.start_jump()
		machine.transition_to(&"Air")
		return
	if player.weapon != null and player.input_buffer.has_pressed(&"attack"):
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_start_variant(player.weapon.dash_attack):
			player.input_buffer.consume(&"attack")
			return
	var has_input := player.get_move_input().length_squared() > 0.01
	if has_input and Input.is_action_just_pressed("crouch"):
		machine.transition_to(&"Slide")
		return
	if not Input.is_action_pressed("dodge") or not has_input:
		machine.transition_to(&"Locomotion")
		return
	player.apply_horizontal_movement(delta, player.dash_speed)
	player.face_input(delta)
