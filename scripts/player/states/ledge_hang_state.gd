class_name LedgeHangState
extends State
## Hanging from a ledge (entered from a grab with interact held). Stays here until the
## player acts: a fresh interact press = climb up, crouch = drop, jump = leap away,
## left/right = shimmy along the one straight ledge line (stops where the ledge ends or
## at corners). Holding toward the wall does nothing.

## Below this much sideways input the player does not shimmy.
const SHIMMY_DEADZONE: float = 0.2

var _normal: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _snap_time: float = 0.0


func enter(_previous: StringName) -> void:
	_normal = player.ledge_wall_normal
	_start = player.global_position
	_snap_time = 0.0
	player.velocity = Vector3.ZERO
	player.coyote_timer = 0.0
	player.input_buffer.clear(&"jump")
	player.snap_facing(-_normal)
	player.reset_air_actions()
	player.play_climb_arms()
	Sfx.play(player.get_tree(), Sfx.Id.LEDGE_GRAB)


func exit(next: StringName) -> void:
	if next != &"LedgeClimb":
		player.release_arms()


func physics_update(delta: float) -> void:
	player.velocity = Vector3.ZERO
	if _snap_time < player.hang_snap_time:
		_snap_time += delta
		var u := smoothstep(0.0, 1.0, clampf(_snap_time / maxf(player.hang_snap_time, 0.001), 0.0, 1.0))
		player.global_position = _start.lerp(player.ledge_hang_pos, u)
		return
	if Input.is_action_just_pressed("crouch"):
		_drop()
		return
	if player.input_buffer.consume(&"jump"):
		_leap()
		return
	var want := player.get_move_input()
	want.y = 0.0
	if Input.is_action_just_pressed("interact"):
		var probe := player.probe_hang_ledge(player.global_position, _normal)
		if not probe.is_empty() and probe["fits"]:
			player.ledge_stand_pos = probe["stand_position"]
			player.ledge_top_y = probe["top_y"]
			player.ledge_wall_normal = _normal
			machine.transition_to(&"LedgeClimb")
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
	var probe := player.probe_hang_ledge(candidate, _normal)
	if probe.is_empty() or not player.can_hang_at(candidate):
		return
	player.global_position = candidate
	player.ledge_top_y = probe["top_y"]


func _drop() -> void:
	_block_regrab()
	machine.transition_to(&"Air")


func _leap() -> void:
	_block_regrab()
	player.wall_normal = _normal
	player.wall_jump_forced_away = true
	machine.transition_to(&"WallJump")


func _block_regrab() -> void:
	player.ledge_block_until_ms = Time.get_ticks_msec() + int(player.ledge_regrab_cooldown * 1000.0)