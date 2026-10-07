class_name GuardState
extends State
## Guard, deflect, jump guard, jump deflect (Step 5), on the ground and in the air.
##
## A fresh guard press opens a deflect window (Combatant.press_guard(): 0.2 s, shrinking with
## rapid presses). While the state lasts the guard is up (a 90 degree cone in front blocks hits);
## the Combatant decides deflect, guard, or hit when a hit arrives. Holding does not extend the
## window; every deflect needs a new press, and a new press mid-guard starts a new window at once
## (a slightly early press is buffered). Releasing ends the guard, but never before the window has
## run out, so a quick tap still gives its full deflect.
## Forced walk (Player.walk_only); you turn toward your movement input like walking.
## Guard from sheathed snaps the sword drawn with a guard-draw pose (SwordVisual.play_guard).
## Cancels: jump, dodge, and attack (and the wall jump or air attack in the air). Guard itself
## cancels any action outside its hit window (see ActionState._try_guard_cancel).

var _airborne: bool = false


func enter(_previous: StringName) -> void:
	var was_sheathed := player.sheathed
	player.sheathed = false
	player.sheathe_idle = 0.0
	player.walk_only = true
	player.combatant.guarding = true
	player.input_buffer.consume(&"guard")
	player.combatant.press_guard()
	_airborne = not player.is_on_floor()
	if player.sword_visual != null:
		player.sword_visual.play_guard(was_sheathed)


func exit(_next: StringName) -> void:
	player.walk_only = false
	player.combatant.guarding = false
	player.notify_combat()
	if player.sword_visual != null:
		player.sword_visual.end_combo()


func physics_update(delta: float) -> void:
	var combatant := player.combatant
	# A fresh press: a new window, even mid-deflect.
	if player.input_buffer.consume(&"guard"):
		combatant.press_guard()
		if player.sword_visual != null:
			player.sword_visual.play_guard_press()
	var on_floor := player.is_on_floor()
	if on_floor:
		if _airborne:
			_airborne = false
			player.reset_air_actions()
		if player.input_buffer.consume(&"jump"):
			player.start_jump()
			machine.transition_to(&"Air")
			return
		if player.input_buffer.consume(&"dodge"):
			machine.transition_to(&"Dodge")
			return
		if player.has_combo() and player.input_buffer.consume(&"attack"):
			machine.transition_to(&"Attack")
			return
	else:
		_airborne = true
		player.apply_gravity(delta)
		if player.try_air_jump():
			machine.transition_to(&"WallJump")
			return
		if player.weapon != null and player.input_buffer.has_pressed(&"attack") \
				and not player.is_near_ground():
			var air_attack := machine.get_node_or_null("AirAttack") as AirAttackState
			if air_attack != null and air_attack.start():
				player.input_buffer.consume(&"attack")
				return
	player.apply_horizontal_movement(delta, player.get_move_speed())
	player.face_input(delta)
	if not Input.is_action_pressed("guard") and combatant.deflect_left <= 0.0:
		machine.transition_to(&"Locomotion" if on_floor else &"Air")
