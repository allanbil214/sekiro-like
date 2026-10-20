class_name WallHugState
extends State
## The wall hug (Phase 2 item 9): back pressed to a wall on the ground. Entered from Locomotion or Crouch
## by `Player.try_interact()` (an `interact` press with nothing to interact with, a wall within reach in
## front of the player). The character turns her back to the wall, keeps her stance (standing or
## crouched), and sidles along it at `wall_hug_speed`, silent (`wall_hug_noise`) and harder to see
## (`wall_hug_sight_multiplier`, read by `EnemyAwareness`). At the open end of a wall, pressing toward it
## shifts the camera past the corner (a peek).
##
## Corners (item 14a): an inside corner (the wall turns toward you) is turned by pushing into it; an
## outside corner (the wall ends and its side face continues) is turned by pressing `interact` while
## peeking past it and holding that direction. Both are a short scripted turn, 90 degrees only.
##
## Leaving: `interact` again, moving away from the wall, a jump, dodge, attack or guard press (the press
## is left in the buffer, so Locomotion or Crouch runs it next frame with all its usual rules, a
## stealth kill included), being hit, or the wall going away. All the numbers are on the Player.

## Below this much sideways input the player does not sidle.
const SIDLE_DEADZONE: float = 0.2
## How far ahead (m) along the wall the sidle checks that the wall continues.
const LOOKAHEAD: float = 0.12
## Seconds after entering during which "moving away" does not leave the hug.
const EXIT_GRACE: float = 0.25
## An inside corner turns when the wall ahead is this close (m) to the body.
const INSIDE_TRIGGER: float = 0.15
## Outside corner: how far (m) behind the front face the body is placed on the side face (tried in order).
const OUTSIDE_DEPTHS: Array[float] = [0.3, 0.35, 0.4, 0.25, 0.2, 0.15, 0.1]

## Points from the wall toward the player.
var _normal: Vector3 = Vector3.ZERO
var _start: Vector3 = Vector3.ZERO
var _goal: Vector3 = Vector3.ZERO
var _snap_time: float = 0.0
var _age: float = 0.0
var _pending_normal: Vector3 = Vector3.ZERO
var _pending_goal: Vector3 = Vector3.ZERO
## The side (+1 or -1 along the wall) the camera is peeking toward, or 0. It stays until the player pushes
## the other way.
var _peek_side: float = 0.0

# The corner turn (a curved path from the old spot to the one on the new wall).
var _turning: bool = false
## Set when a turn ends: the direction held through the turn can point away from the new wall, so
## pushing away does not leave the hug until it has been let go once.
var _push_lock: bool = false
var _turn_time: float = 0.0
var _turn_from: Vector3 = Vector3.ZERO
var _turn_control: Vector3 = Vector3.ZERO
var _turn_to: Vector3 = Vector3.ZERO
var _turn_normal: Vector3 = Vector3.ZERO


## Called by `Player.try_interact()`. Looks for a wall in front and, if there is one, switches to this
## state and returns true.
func try_begin() -> bool:
	if not player.is_on_floor():
		return false
	var wall := player.ledge_sensor.find_wall()
	if wall.is_empty():
		return false
	var normal: Vector3 = wall["normal"]
	if player.get_facing_direction().dot(-normal) < player.wall_hug_facing_dot:
		return false
	var hit_position: Vector3 = wall["position"]
	_pending_normal = normal
	_pending_goal = Vector3(hit_position.x, player.global_position.y, hit_position.z) \
			+ normal * (player.wall_hug_radius + player.wall_hug_gap)
	player.input_buffer.consume(Actions.INTERACT)
	machine.transition_to(StateName.WALL_HUG)
	return true


func enter(_previous: StringName) -> void:
	_normal = _pending_normal
	_goal = _pending_goal
	_start = player.global_position
	_snap_time = 0.0
	_age = 0.0
	_peek_side = 0.0
	_turning = false
	_push_lock = false
	player.velocity = Vector3.ZERO
	player.snap_facing(_normal)
	# The slim "pillar" body (the position was already worked out with this radius).
	player.set_body_radius(player.wall_hug_radius)


func exit(next: StringName) -> void:
	_set_peek(Vector3.ZERO)
	# Step away from the wall by the radius that comes back, so the full body does not start inside it.
	var grow := player.get_default_body_radius() - player.get_body_radius()
	if grow > 0.0:
		player.move_and_collide(_normal * grow)
	player.set_body_radius(player.get_default_body_radius())
	# Crouch keeps the stance; anything else stands up (as leaving Crouch does).
	if player.is_crouched and next != StateName.CROUCH:
		player.set_crouched(false)


func physics_update(delta: float) -> void:
	_age += delta
	if not player.is_on_floor():
		machine.transition_to(StateName.AIR)
		return
	player.velocity.x = 0.0
	player.velocity.z = 0.0
	if _snap_time < player.wall_hug_snap_time:
		_snap_time += delta
		var u := smoothstep(0.0, 1.0, clampf(_snap_time / maxf(player.wall_hug_snap_time, 0.001), 0.0, 1.0))
		player.global_position = _start.lerp(_goal, u)
		return
	if _turning:
		_update_turn(delta)
		return
	var want := player.get_move_input()
	want.y = 0.0
	if Input.is_action_just_pressed(Actions.INTERACT):
		# Peeking past an outside corner and holding that way: turn around it. Otherwise leave.
		if not _try_outside_turn(want):
			_leave()
		return
	if _wants_action():
		_leave()
		return
	var pushing_away := want.dot(_normal) > player.wall_hug_exit_dot
	if not pushing_away:
		_push_lock = false
	if _age > EXIT_GRACE and pushing_away and not _push_lock:
		_leave()
		return
	if _probe(player.global_position).is_empty():
		_leave()
		return
	_sidle(want)


## Called when the player is hit while hugging.
func knock_off() -> void:
	_leave()


## A press that Locomotion or Crouch should handle: it stays in the buffer.
func _wants_action() -> bool:
	return player.input_buffer.has_pressed(Actions.JUMP) or player.input_buffer.has_pressed(Actions.DODGE) \
			or player.input_buffer.has_pressed(Actions.ATTACK) or player.input_buffer.has_pressed(Actions.GUARD)


func _sidle(want: Vector3) -> void:
	var tangent := _normal.cross(Vector3.UP).normalized()
	var lateral := clampf(want.dot(tangent), -1.0, 1.0)
	var side := signf(lateral) if absf(lateral) >= SIDLE_DEADZONE else 0.0
	if _peek_side != 0.0:
		if side == -_peek_side:
			# Pushing the other way ends the peek and sidles back.
			_peek_side = 0.0
		else:
			_set_peek(tangent * _peek_side * player.wall_hug_peek_distance)
			return
	if side == 0.0:
		_set_peek(Vector3.ZERO)
		return
	if _try_inside_turn(tangent * side):
		return
	var ahead := _probe(player.global_position + tangent * side * LOOKAHEAD)
	if ahead.is_empty():
		# The wall ends here: stop at the edge and peek past it (it stays until pushed the other way).
		_peek_side = side
		_set_peek(tangent * side * player.wall_hug_peek_distance)
		return
	var ahead_normal: Vector3 = ahead["normal"]
	if ahead_normal.dot(_normal) < 0.9:
		# An inside corner: stop, no peek.
		_set_peek(Vector3.ZERO)
		return
	_set_peek(Vector3.ZERO)
	player.velocity.x = tangent.x * lateral * player.wall_hug_speed
	player.velocity.z = tangent.z * lateral * player.wall_hug_speed


## Pushing into an inside corner (a wall right ahead along the sidle, facing back at us): turn onto it.
func _try_inside_turn(dir: Vector3) -> bool:
	var origin := _chest(player.global_position)
	var length := player.get_body_radius() + INSIDE_TRIGGER
	var hit := _ray(origin, origin + dir * length)
	if hit.is_empty():
		return false
	var flat := _flat(hit["normal"])
	if flat.dot(-dir) < 0.9:
		return false
	var hit_pos: Vector3 = hit["position"]
	var goal := Vector3(hit_pos.x, player.global_position.y, hit_pos.z) \
			+ flat * (player.wall_hug_radius + player.wall_hug_gap)
	if not _spot_ok(goal, flat):
		return false
	_start_turn(goal, (player.global_position + goal) * 0.5, flat)
	return true


## `interact` while peeking past the end of a wall and holding that way: looks for the side face of a
## square outside corner and turns onto it.
func _try_outside_turn(want: Vector3) -> bool:
	if _peek_side == 0.0:
		return false
	var tangent := _normal.cross(Vector3.UP).normalized()
	var lateral := clampf(want.dot(tangent), -1.0, 1.0)
	if absf(lateral) < SIDLE_DEADZONE or signf(lateral) != _peek_side:
		return false
	var dir := tangent * _peek_side
	var pos := player.global_position
	var face_distance := player.wall_hug_radius + player.wall_hug_gap
	# A ray back toward the wall's end from beyond the corner, just behind its front face, finds the side face.
	var origin := _chest(pos) + dir * player.wall_hug_corner_reach - _normal * (face_distance + 0.1)
	var hit := _ray(origin, origin - dir * (player.wall_hug_corner_reach + 0.2))
	if hit.is_empty():
		return false
	var flat := _flat(hit["normal"])
	if flat.dot(dir) < 0.9:
		return false
	var hit_pos: Vector3 = hit["position"]
	var along := (hit_pos - pos).dot(dir)
	var control := pos + dir * (along + face_distance * 1.3) + _normal * (face_distance * 0.3)
	var on_face := pos + dir * (along + face_distance)
	for depth: float in OUTSIDE_DEPTHS:
		var goal := on_face - _normal * (face_distance + depth)
		goal.y = pos.y
		if _spot_ok(goal, dir):
			_start_turn(goal, control, dir)
			return true
	return false


## True if the hug fits at `feet` against a wall with `normal`: the wall is found by the hug's own probe,
## there is floor under it and the body fits.
func _spot_ok(feet: Vector3, normal: Vector3) -> bool:
	if _probe_at(feet, normal).is_empty():
		return false
	var mask := player.collision_mask & ~Layers.INVISIBLE_WALL
	var down := PhysicsRayQueryParameters3D.create(feet + Vector3.UP * 0.3, feet + Vector3.DOWN * 0.3, mask, [player.get_rid()])
	var floor_hit := player.get_world_3d().direct_space_state.intersect_ray(down)
	if floor_hit.is_empty() or absf((floor_hit["position"] as Vector3).y - feet.y) > 0.15:
		return false
	var at := feet + Vector3.UP * 0.02
	return player.fits_crouching_at(at) if player.is_crouched else player.fits_standing_at(at)


func _start_turn(goal: Vector3, control: Vector3, new_normal: Vector3) -> void:
	_set_peek(Vector3.ZERO)
	_peek_side = 0.0
	player.input_buffer.consume(Actions.INTERACT)
	_turning = true
	_turn_time = 0.0
	_turn_from = player.global_position
	_turn_control = control
	_turn_to = goal
	_turn_normal = new_normal


## Moves along the curve and turns the body; the input is ignored until the turn is done.
func _update_turn(delta: float) -> void:
	player.velocity = Vector3.ZERO
	_turn_time += delta
	var t := clampf(_turn_time / maxf(player.wall_hug_corner_time, 0.001), 0.0, 1.0)
	var u := smoothstep(0.0, 1.0, t)
	var a := _turn_from.lerp(_turn_control, u)
	var b := _turn_control.lerp(_turn_to, u)
	player.global_position = a.lerp(b, u)
	player.snap_facing(_normal.slerp(_turn_normal, u))
	if t < 1.0:
		return
	_turning = false
	_push_lock = true
	_normal = _turn_normal
	_goal = _turn_to
	player.global_position = _turn_to
	player.snap_facing(_normal)


func _chest(feet: Vector3) -> Vector3:
	var height := player.crouch_height if player.is_crouched else player.stand_height
	return feet + Vector3.UP * (height * 0.5)


func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var mask := player.collision_mask & ~Layers.INVISIBLE_WALL
	var query := PhysicsRayQueryParameters3D.create(from, to, mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty() or absf((hit["normal"] as Vector3).y) > 0.3:
		return {}
	return hit


func _flat(normal: Vector3) -> Vector3:
	return Vector3(normal.x, 0.0, normal.z).normalized()


## A ray from the chest toward the wall at `feet`. Returns {"normal"} of a wall hit, or {}.
func _probe(feet: Vector3) -> Dictionary:
	return _probe_at(feet, _normal)


## Like _probe(), for a wall whose normal (toward the player) is `normal`.
func _probe_at(feet: Vector3, normal: Vector3) -> Dictionary:
	var height := player.crouch_height if player.is_crouched else player.stand_height
	var origin := feet + Vector3.UP * (height * 0.5)
	var length := player.get_body_radius() + player.wall_hug_edge_reach
	var mask := player.collision_mask & ~Layers.INVISIBLE_WALL
	var query := PhysicsRayQueryParameters3D.create(origin, origin - normal * length, mask, [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_normal: Vector3 = hit["normal"]
	if absf(hit_normal.y) > 0.3:
		return {}
	return {"normal": Vector3(hit_normal.x, 0.0, hit_normal.z).normalized()}


func _set_peek(offset: Vector3) -> void:
	var rig := player.camera_rig as CameraRig
	if rig != null:
		rig.set_peek(offset)


func _leave() -> void:
	machine.transition_to(StateName.CROUCH if player.is_crouched else StateName.LOCOMOTION)