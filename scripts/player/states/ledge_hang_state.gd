class_name LedgeHangState
extends State
## Hanging from a ledge (entered from a grab with interact held). Stays here until the
## player acts: a fresh interact press = climb up, crouch = drop, jump = leap away,
## left/right = shimmy along the ledge. At the end of the ledge, a square corner (inside or
## outside, 90 degrees) is turned with a short scripted blend; any other end stops the shimmy.
## Holding toward the wall does nothing.

## Below this much sideways input the player does not shimmy.
const SHIMMY_DEADZONE: float = 0.2

var _normal: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _snap_time: float = 0.0

# The corner turn (a curved path from the old hang spot to the one on the new wall).
var _turning: bool = false
var _turn_time: float = 0.0
var _turn_from: Vector3 = Vector3.ZERO
var _turn_control: Vector3 = Vector3.ZERO
var _turn_to: Vector3 = Vector3.ZERO
var _turn_normal: Vector3 = Vector3.ZERO
var _turn_top_y: float = 0.0


func enter(_previous: StringName) -> void:
	_normal = player.ledge_wall_normal
	_start = player.global_position
	_snap_time = 0.0
	_turning = false
	player.velocity = Vector3.ZERO
	player.coyote_timer = 0.0
	player.input_buffer.clear(Actions.JUMP)
	player.snap_facing(-_normal)
	player.reset_air_actions()
	player.play_climb_arms()
	Sfx.play(player.get_tree(), Sfx.Id.LEDGE_GRAB)


func exit(next: StringName) -> void:
	if next != StateName.LEDGE_CLIMB:
		player.release_arms()


func physics_update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if _snap_time < player.hang_snap_time:
		_snap_time += delta
		var u := smoothstep(0.0, 1.0, clampf(_snap_time / maxf(player.hang_snap_time, 0.001), 0.0, 1.0))
		player.global_position = _start.lerp(player.ledge_hang_pos, u)
		return
	if _turning:
		_update_turn(delta)
		return
	if Input.is_action_just_pressed(Actions.CROUCH):
		_drop()
		return
	if player.input_buffer.consume(Actions.JUMP):
		_leap()
		return
	var want := player.get_move_input()
	want.y = 0.0
	if Input.is_action_just_pressed(Actions.INTERACT):
		var probe := player.ledge_sensor.probe_hang_ledge(player.global_position, _normal)
		if not probe.is_empty() and probe["fits"]:
			player.ledge_stand_pos = probe["stand_position"]
			player.ledge_top_y = probe["top_y"]
			player.ledge_wall_normal = _normal
			machine.transition_to(StateName.LEDGE_CLIMB)
		return
	_shimmy(want, delta)


## Called by the damage system later (Step 4) when the player is hit while hanging.
func knock_off() -> void:
	_drop()


func _shimmy(want: Vector3, delta: float) -> void:
	var tangent := _normal.cross(Vector3.UP).normalized()
	var lateral := clampf(want.dot(tangent), -1.0, 1.0)
	if absf(lateral) < SHIMMY_DEADZONE:
		return
	var candidate := player.global_position + tangent * lateral * player.shimmy_speed * delta
	var probe := player.ledge_sensor.probe_hang_ledge(candidate, _normal)
	if probe.is_empty() or not player.ledge_sensor.can_hang_at(candidate):
		_try_corner(tangent * signf(lateral))
		return
	player.global_position = candidate
	player.ledge_top_y = probe["top_y"]


## At the end of the ledge: starts the corner turn if there is a square corner in that direction.
func _try_corner(dir: Vector3) -> void:
	var corner := player.ledge_sensor.find_corner(player.global_position, _normal, dir)
	if corner.is_empty():
		return
	_turning = true
	_turn_time = 0.0
	_turn_from = player.global_position
	_turn_control = corner["control"]
	_turn_to = corner["position"]
	_turn_normal = corner["normal"]
	_turn_top_y = corner["top_y"]


## Moves along the curve and turns the body; the input is ignored until the turn is done.
func _update_turn(delta: float) -> void:
	_turn_time += delta
	var t := clampf(_turn_time / maxf(player.corner_turn_time, 0.001), 0.0, 1.0)
	var u := smoothstep(0.0, 1.0, t)
	var a := _turn_from.lerp(_turn_control, u)
	var b := _turn_control.lerp(_turn_to, u)
	player.global_position = a.lerp(b, u)
	player.snap_facing((-_normal).slerp(-_turn_normal, u))
	if t < 1.0:
		return
	_turning = false
	_normal = _turn_normal
	player.global_position = _turn_to
	player.ledge_wall_normal = _normal
	player.ledge_top_y = _turn_top_y
	player.ledge_hang_pos = _turn_to
	player.snap_facing(-_normal)


func _drop() -> void:
	_block_regrab()
	machine.transition_to(StateName.AIR)


func _leap() -> void:
	_block_regrab()
	player.wall_normal = _normal
	player.wall_jump_forced_away = true
	machine.transition_to(StateName.WALL_JUMP)


func _block_regrab() -> void:
	player.ledge_block_until_ms = Time.get_ticks_msec() + int(player.ledge_regrab_cooldown * 1000.0)