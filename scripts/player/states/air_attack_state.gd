class_name AirAttackState
extends ActionState
## Air tap loop (3b-3). Pressing attack while airborne plays Player.weapon.air_attack, and a
## chained tap follows ActionData.combo_next (the second loops back to the first). The loop is
## unlimited while airborne and restarts from the first attack after landing.
##
## No lunge and no hover: gravity and air control carry on as in the Air state, and the body
## can turn toward the movement input during the wind-up. Cancels (outside the hit window): a
## wall jump or mid-air reach (jump), a ledge grab, and on the floor dodge, jump, and crouch.
## Landing mid-swing lets the swing play out; a tap queued by then continues the ground combo
## at attack 2 (an air attack counts as combo step 1). Holding attack does nothing yet (the
## helm splitter is 3b-4). No hitboxes or damage yet (Step 4).

var _queued: bool = false


## Called by the Air state when attack is pressed in the air. Returns false if the weapon has
## no air attack.
func start() -> bool:
	if player.weapon == null or player.weapon.air_attack == null:
		return false
	machine.transition_to(&"AirAttack")
	return true


func enter(previous: StringName) -> void:
	var next := player.air_loop_next
	action = next if next != null else player.weapon.air_attack
	player.air_loop_next = action.combo_next
	super.enter(previous)


func exit(next: StringName) -> void:
	super.exit(next)
	# A chain (air or ground) carries the sword's pose over; anything else lets it rest.
	if next != &"AirAttack" and next != &"Attack" and player.sword_visual != null:
		player.sword_visual.end_combo()


func get_debug_text() -> String:
	var phase := "wind-up"
	if action.is_hit_active(action_time):
		phase = "ACTIVE"
	elif action_time >= action.active_hit.y:
		phase = "recovery"
	return "Air attack (%s)%s\nBuffer: %s  Chain: %s  Queued: %s" % [
		phase, "" if not player.is_on_floor() else " landed",
		"open" if _in_buffer_window() else "-",
		"open" if action_time >= _chain_time() else "-", _queued,
	]


func _on_action_enter(_previous: StringName) -> void:
	_queued = false
	if player.sword_visual != null:
		player.sword_visual.begin_action(action)


func _on_action_update(delta: float) -> void:
	# Landing resets the air actions (and the loop), even while the swing plays out.
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
	if action_time < action.active_hit.x:
		player.face_input(delta)
	if player.sword_visual != null:
		player.sword_visual.update_action(action, action_time)
	_accept_attack_press()
	if action.is_hit_active(action_time):
		return
	if _try_cancel():
		return
	if _queued and action_time >= _chain_time():
		_chain()


## No lunge: air control while airborne, braking once the swing has landed.
func _apply_action_movement(delta: float) -> void:
	if player.is_on_floor():
		player.decelerate(delta)
	else:
		player.apply_horizontal_movement(delta, player.get_move_speed())


func _on_action_finished() -> void:
	if player.is_on_floor():
		super()
	else:
		machine.transition_to(&"Air")


## The next tap: another air attack, or (landed) the ground combo from attack 2.
func _chain() -> void:
	if player.is_on_floor():
		var attack := machine.get_node_or_null("Attack") as AttackState
		if attack != null and attack.try_continue_combo(1):
			return
	machine.transition_to(&"AirAttack")


func _try_cancel() -> bool:
	if player.is_on_floor():
		if player.input_buffer.consume(&"dodge"):
			machine.transition_to(&"Dodge")
			return true
		if player.input_buffer.consume(&"jump"):
			player.start_jump()
			machine.transition_to(&"Air")
			return true
		if Input.is_action_just_pressed("crouch"):
			machine.transition_to(&"Crouch")
			return true
		return false
	if player.try_ledge_grab():
		machine.transition_to(player.ledge_grab_state())
		return true
	if player.try_air_jump():
		machine.transition_to(&"WallJump")
		return true
	return false


func _accept_attack_press() -> void:
	if _queued:
		return
	if _in_buffer_window() and player.input_buffer.consume(&"attack"):
		_queued = true


func _in_buffer_window() -> bool:
	var window := action.buffer_window
	if window == Vector2.ZERO:
		return true
	return action_time >= window.x and action_time <= window.y


## Earliest time the next attack may start: where the cancel window opens.
func _chain_time() -> float:
	if action.cancel_window == Vector2.ZERO:
		return action.locked_until
	return action.cancel_window.x
