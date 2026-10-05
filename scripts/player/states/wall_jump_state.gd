class_name WallJumpState
extends ActionState
## Wall jump, started from the Air state when jump is pressed near a wall. The push
## direction comes from the movement input relative to the wall: toward = straight up,
## away or no input = off the wall, sideways = along the wall. Up speed and push speed
## are boosted by Player.wall_jump_boost. The horizontal burst comes from the action's
## move window (move_speed is multiplied by the boost here).


func _on_action_enter(_previous: StringName) -> void:
	# A leap from a ledge hang always goes away from the wall and does not use up a wall jump.
	var forced_away := player.wall_jump_forced_away
	player.wall_jump_forced_away = false
	var normal := player.wall_normal
	var input := player.get_move_input()
	input.y = 0.0
	var has_input := input.length_squared() > 0.01
	var dir := normal
	var facing := normal
	if has_input:
		var want := input.normalized()
		if want.dot(-normal) >= player.wall_input_threshold:
			dir = Vector3.ZERO
			facing = -normal
		elif want.dot(normal) >= player.wall_input_threshold:
			dir = normal
			facing = normal
		else:
			dir = (want - normal * want.dot(normal)).normalized()
			facing = dir
	if forced_away:
		dir = normal
		facing = normal
	_move_dir = dir
	_move_speed_multiplier = player.wall_jump_boost
	player.snap_facing(facing)
	player.velocity.y = player.jump_velocity * player.wall_jump_boost
	player.coyote_timer = 0.0
	if not forced_away:
		player.wall_jumps_used += 1
	player.reach_ready = true
	player.play_reach_arms()


func _on_action_update(_delta: float) -> void:
	if player.is_on_floor() and player.velocity.y <= 0.0:
		player.reset_air_actions()
		machine.transition_to(&"Locomotion")
		return
	if player.try_ledge_grab():
		machine.transition_to(player.ledge_grab_state())
		return
	if action.can_cancel(action_time) and player.try_air_jump():
		machine.transition_to(&"WallJump")


func _on_action_finished() -> void:
	machine.transition_to(&"Air")
