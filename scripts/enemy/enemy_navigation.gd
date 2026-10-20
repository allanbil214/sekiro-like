class_name EnemyNavigation
extends RefCounted
## Phase 2 item 12a: navmesh pathing for one Enemy (the enemy makes it in _ready() when `use_navigation` is on).
##
## It wraps the enemy's `NavigationAgent` child node: `direction_to(point)` returns the flat unit direction of
## the next step on the path to the point, and the caller (EnemyAwareness._walk_to, Enemy._update_chase) steers
## with it exactly as it did with the straight line. Everything else stays with the callers: the edge guard, the
## stuck timer, the arrival distance and the vertical reach. The path index is kept here, not read from the
## agent. It only walks: a navmesh has no climbing, so a
## target on another level ends at the closest point of the mesh (the enemy stands there).
##
## Item 12b-1a, drop links: an enemy with `use_nav_links` also takes the one-way `NavigationLink3D` nodes on
## navigation layer 2 (its agent gets layers 1 and 2; an enemy without the switch never sees them). When the path
## runs over a link and the enemy reaches the entry, `_begin_crossing()` takes over: a pause at the edge, the step
## off toward the exit (the edge guard does not apply), the fall, and a short recovery. The Enemy calls
## `tick_crossing()` instead of its AI while `is_crossing()`.
##
## Item 12b-2, jump links: a `NavigationLink3D` on navigation layer 4 (usually bidirectional) across a gap. The
## agent gets layer 4 only when the preset's `nav_jump_max_distance` is above 0 (0 = this enemy type never jumps).
## The kind of a link on the path is read from the layer of the link node that owns its path points. A jump is
## the same crossing with an arc: the pause at the edge, then a launch whose speed is computed so that the arc
## lands on the exit (flight time = distance / `nav_jump_speed`), no steering in the air, a landing and the
## recovery.
##
## Item 12b-3, climb links: a `NavigationLink3D` on navigation layer value 8 (the fourth checkbox), usually
## bidirectional, from the ground at the foot of a wall to the top of the platform. The agent gets layer 8 only
## when the preset's `nav_climb_max_height` is above 0 (0 = this enemy type never climbs). A climb has two legs
## so it never cuts through the wall's corner: straight up (or down) at the foot of the wall, then a horizontal
## move at the top; the enemy moves along them at `nav_climb_speed` with gravity not acting, and then recovers.
##
## A missing agent node, an arena without a baked navmesh, or a path that cannot be found is reported once and
## answered with a zero direction (the enemy stands and its stuck timer gives up), never with a hidden
## straight-line walk, so a missing bake shows up while testing.

var _enemy: Enemy
var _ai: EnemyAIData
var _agent: NavigationAgent3D
var _target: Vector3 = Vector3.ZERO
var _has_target: bool = false
var _last_path_msec: int = 0
var _warned_no_path: bool = false
var _next_log_msec: int = 0
var _last_path: PackedVector3Array = PackedVector3Array()
var _index: int = 0

enum Cross { NONE, PAUSE, STEP, AIR, CLIMB, RECOVER }
enum Link { NONE, DROP, JUMP, CLIMB }
const LINK_LAYER_BIT: int = 2 # NavigationLink3D.navigation_layers value (layer 2): drop links
const JUMP_LAYER_BIT: int = 4 # value 4 (the third layer checkbox): jump links
const CLIMB_LAYER_BIT: int = 8 # value 8 (the fourth layer checkbox): climb links
const CLIMB_ARRIVE: float = 0.12 # m from a climb waypoint that counts as reached
const CLIMB_MARGIN: float = 3.0 # s added to the expected climb time before it is given up
const CROSS_STEP_TIMEOUT: float = 2.5 # s from the first step to leaving the floor
const CROSS_TOTAL_TIMEOUT: float = 8.0 # s for the whole crossing
const MISS_DEPTH: float = 3.5 # m below the exit that means a jump fell short
const LINK_TYPE: int = 1 # NavigationPathQueryResult3D.PATH_SEGMENT_TYPE_LINK
var _cross: Cross = Cross.NONE
var _cross_kind: Link = Link.NONE
var _climb_corner: Vector3 = Vector3.ZERO
var _climb_leg: int = 0
var _climb_time_left: float = 0.0
var _link_kind: Link = Link.NONE # the kind of the link `_find_link()` found last
var _cross_timer: float = 0.0
var _cross_elapsed: float = 0.0
var _cross_step_elapsed: float = 0.0
var _cross_entry_y: float = 0.0
var _cross_exit: Vector3 = Vector3.ZERO
var _left_floor: bool = false
var _warned_cross: bool = false


func _init(enemy: Enemy) -> void:
	_enemy = enemy
	_ai = enemy.ai


## Finds the agent and applies the numbers from the AI preset. False (and one error) when the node is missing.
func setup() -> bool:
	_agent = _enemy.get_node_or_null("NavigationAgent") as NavigationAgent3D
	if _agent == null:
		push_error("EnemyNavigation: `use_navigation` is on but %s has no NavigationAgent3D child named \"NavigationAgent\"." % _enemy.name)
		return false
	_agent.path_desired_distance = _ai.nav_path_desired_distance
	_agent.target_desired_distance = _ai.nav_target_desired_distance
	_agent.avoidance_enabled = false
	_agent.debug_enabled = _enemy.debug_navigation
	if _enemy.use_nav_links:
		var bits: int = LINK_LAYER_BIT
		if _ai.nav_jump_max_distance > 0.0:
			bits |= JUMP_LAYER_BIT
		if _ai.nav_climb_max_height > 0.0:
			bits |= CLIMB_LAYER_BIT
		_agent.navigation_layers = _agent.navigation_layers | bits
	return true


## The flat unit direction toward the next path point, or zero when there is nothing to follow.
func direction_to(point: Vector3) -> Vector3:
	if _agent == null or _cross != Cross.NONE:
		return Vector3.ZERO
	var map: RID = _agent.get_navigation_map()
	if NavigationServer3D.map_get_iteration_id(map) == 0:
		_log("MAP NOT SYNCED", point, map)
		return Vector3.ZERO # the navigation map has not synchronized yet (the first physics frames)
	_update_target(point)
	# Calling this makes the agent compute its path. Its own path index and "finished" flag are not used: they
	# stay on the first point (the enemy's own position) while the enemy stands, so it would never leave.
	_agent.get_next_path_position()
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	if path.is_empty():
		if not _warned_no_path:
			_warned_no_path = true
			push_warning("EnemyNavigation: %s found no path (is the NavigationRegion3D baked?)." % _enemy.name)
		_log("EMPTY PATH", point, map)
		return Vector3.ZERO
	if path != _last_path:
		_last_path = path # a new path: start again from its first point
		_index = 0
	var here: Vector3 = _enemy.global_position
	var reach: float = _ai.nav_path_desired_distance
	var link_at: int = _find_link(path) if _enemy.use_nav_links else -1
	var last: int = path.size() if link_at < 0 else link_at + 1 # with a link the walk ends at its entry
	while _index < last and _flat_distance(here, path[_index]) <= reach:
		_index += 1
	if link_at >= 0:
		# The edge guard stops the walk a little before the edge, so the entry counts from a bit further out.
		var trigger: float = maxf(reach, _ai.edge_probe_distance + 0.2)
		if _enemy.is_on_floor() and _flat_distance(here, path[link_at]) <= trigger:
			if _begin_crossing(path[link_at], path[link_at + 1], _link_kind):
				_log("LINK", point, map)
				return Vector3.ZERO
			_log("LINK UNUSABLE", point, map)
			return Vector3.ZERO
	if _index >= path.size():
		_log("PATH DONE", point, map)
		return Vector3.ZERO # the end of the path (the target, or the closest point of the mesh to it)
	var flat := Vector3(path[_index].x - here.x, 0.0, path[_index].z - here.z)
	_log("WALKING", point, map)
	return flat.normalized()


## The index of the entry point of the first link on the path (its exit is the next point), or -1, and sets
## `_link_kind`. Godot marks only the entry point of a link as a link point in the path types (the exit is typed
## as the region after it); the layer of the link node that owns the point tells a jump (value 4) or a climb
## (value 8) from a drop.
## A steep fall between two close points (steeper than any walkable slope) also counts as a drop, in case the
## types do not mark it.
func _find_link(path: PackedVector3Array) -> int:
	var result: NavigationPathQueryResult3D = _agent.get_current_navigation_result()
	var types: PackedInt32Array = result.path_types
	var owners: PackedInt64Array = result.path_owner_ids
	var typed: bool = types.size() == path.size()
	var owned: bool = owners.size() == path.size()
	for i in range(path.size() - 1):
		var marked: bool = typed and types[i] == LINK_TYPE # the entry point of a link
		if marked and owned:
			var link := instance_from_id(owners[i]) as NavigationLink3D
			if link == null:
				link = instance_from_id(owners[i + 1]) as NavigationLink3D
			if link != null and (link.navigation_layers & JUMP_LAYER_BIT) != 0:
				_link_kind = Link.JUMP
				return i
			if link != null and (link.navigation_layers & CLIMB_LAYER_BIT) != 0:
				_link_kind = Link.CLIMB
				return i
		var drop: float = path[i].y - path[i + 1].y
		if drop <= 0.5:
			continue
		var steep: bool = drop >= 1.0 and drop > 1.2 * _flat_distance(path[i], path[i + 1])
		if marked or steep:
			_link_kind = Link.DROP
			return i
	_link_kind = Link.NONE
	return -1


func is_crossing() -> bool:
	return _cross != Cross.NONE


## Starts the crossing of a link: false (and one warning) when the fall is longer than `nav_drop_max_height`, a
## jump is wider than `nav_jump_max_distance` or rises more than `nav_jump_max_rise`, or a climb is taller than
## `nav_climb_max_height`.
func _begin_crossing(entry: Vector3, exit: Vector3, kind: Link) -> bool:
	var drop: float = entry.y - exit.y
	var reason: String = ""
	if kind != Link.CLIMB and drop > _ai.nav_drop_max_height:
		reason = "a drop of %.1f m, more than nav_drop_max_height" % drop
	elif kind == Link.CLIMB and absf(drop) > _ai.nav_climb_max_height:
		reason = "a climb of %.1f m, more than nav_climb_max_height" % absf(drop)
	elif kind == Link.JUMP and _flat_distance(entry, exit) > _ai.nav_jump_max_distance:
		reason = "a jump of %.1f m, more than nav_jump_max_distance" % _flat_distance(entry, exit)
	elif kind == Link.JUMP and -drop > _ai.nav_jump_max_rise:
		reason = "a jump rising %.1f m, more than nav_jump_max_rise" % -drop
	if reason != "":
		if not _warned_cross:
			_warned_cross = true
			push_warning("EnemyNavigation: %s found %s." % [_enemy.name, reason])
		return false
	_cross = Cross.PAUSE
	_cross_kind = kind
	_cross_timer = _ai.nav_link_pause
	_cross_elapsed = 0.0
	_cross_step_elapsed = 0.0
	_cross_entry_y = entry.y
	_cross_exit = exit
	_left_floor = false
	if kind == Link.CLIMB:
		# Vertical at the XZ of the lower end, up to the height of the upper end, then horizontal to the exit.
		var lower: Vector3 = entry if exit.y > entry.y else exit
		_climb_corner = Vector3(lower.x, maxf(entry.y, exit.y), lower.z)
		_climb_leg = 0
		_climb_time_left = (entry.distance_to(_climb_corner) + _climb_corner.distance_to(exit)) \
				/ maxf(_ai.nav_climb_speed, 0.1) + CLIMB_MARGIN
	return true


## Called by the Enemy every physics frame while `is_crossing()` (gravity is already applied, the Enemy calls
## `move_and_slide()` after it).
func tick_crossing(delta: float) -> void:
	_cross_elapsed += delta
	var pos: Vector3 = _enemy.global_position
	var flat := Vector3(_cross_exit.x - pos.x, 0.0, _cross_exit.z - pos.z)
	var flat_length: float = flat.length()
	var dir: Vector3 = flat / flat_length if flat_length > 0.01 else Vector3.ZERO
	if dir != Vector3.ZERO:
		var yaw: float = atan2(-dir.x, -dir.z)
		_enemy.rotation.y = lerp_angle(_enemy.rotation.y, yaw, 1.0 - exp(-8.0 * delta))
	if _cross_elapsed > CROSS_TOTAL_TIMEOUT:
		_abort_crossing("took too long")
		return
	match _cross:
		Cross.PAUSE:
			_steer_flat(Vector3.ZERO, delta)
			_cross_timer -= delta
			if _cross_timer <= 0.0:
				if _cross_kind == Link.JUMP:
					_launch(flat)
					_cross = Cross.AIR
				elif _cross_kind == Link.CLIMB:
					_cross = Cross.CLIMB
				else:
					_cross = Cross.STEP
		Cross.STEP:
			var wanted: Vector3 = dir * _ai.nav_drop_step_speed if flat_length > 0.3 else Vector3.ZERO
			_steer_flat(wanted, delta)
			_cross_step_elapsed += delta
			if not _enemy.is_on_floor():
				_left_floor = true
			elif _left_floor and pos.y < _cross_entry_y - 0.5:
				_cross = Cross.RECOVER
				_cross_timer = _ai.nav_link_recovery
			elif not _left_floor and _cross_step_elapsed > CROSS_STEP_TIMEOUT:
				_abort_crossing("never left the floor (is the link start at the edge?)")
		Cross.AIR:
			# No steering in the air: the launch velocity carries it. Landing, or falling short, ends the jump.
			_cross_step_elapsed += delta
			if not _enemy.is_on_floor():
				_left_floor = true
				if pos.y < _cross_exit.y - MISS_DEPTH:
					_abort_crossing("missed the landing")
			elif _left_floor:
				_cross = Cross.RECOVER
				_cross_timer = _ai.nav_link_recovery
			elif _cross_step_elapsed > CROSS_STEP_TIMEOUT:
				_abort_crossing("the jump never left the floor")
		Cross.CLIMB:
			# Two legs, set by position: gravity does not act, the velocity is replaced every frame.
			_climb_time_left -= delta
			var target: Vector3 = _climb_corner if _climb_leg == 0 else _cross_exit
			var to_target: Vector3 = target - pos
			if to_target.length() <= CLIMB_ARRIVE:
				if _climb_leg == 0:
					_climb_leg = 1
				else:
					_cross = Cross.RECOVER
					_cross_timer = _ai.nav_link_recovery
					_enemy.velocity = Vector3.ZERO
			else:
				var speed: float = minf(_ai.nav_climb_speed, to_target.length() / maxf(delta, 0.001))
				_enemy.velocity = to_target.normalized() * speed
				if _climb_time_left <= 0.0:
					_abort_crossing("the climb took too long")
		Cross.RECOVER:
			_steer_flat(Vector3.ZERO, delta)
			_cross_timer -= delta
			if _cross_timer <= 0.0:
				_end_crossing()


## Sets the launch velocity of a jump: the flight time is the flat distance to the exit divided by `nav_jump_speed`
## (at least 0.25 s), the vertical speed is computed from gravity so the arc ends at the exit's height.
func _launch(flat: Vector3) -> void:
	var flight: float = maxf(flat.length() / _ai.nav_jump_speed, 0.25)
	var rise: float = _cross_exit.y - _cross_entry_y
	_enemy.velocity.x = flat.x / flight
	_enemy.velocity.z = flat.z / flight
	_enemy.velocity.y = rise / flight + 0.5 * _enemy.gravity_strength() * flight


func _steer_flat(wanted: Vector3, delta: float) -> void:
	_enemy.velocity.x = move_toward(_enemy.velocity.x, wanted.x, _ai.acceleration * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, wanted.z, _ai.acceleration * delta)


func _abort_crossing(why: String) -> void:
	if not _warned_cross:
		_warned_cross = true
		push_warning("EnemyNavigation: %s gave up a link crossing: %s." % [_enemy.name, why])
	_end_crossing()


## The enemy died or was knocked out mid-crossing.
func cancel_crossing() -> void:
	if _cross != Cross.NONE:
		_end_crossing()


func _end_crossing() -> void:
	_cross = Cross.NONE
	_has_target = false # a fresh path from where it stands now
	_last_path = PackedVector3Array()
	_index = 0


func _flat_distance(a: Vector3, b: Vector3) -> float:
	return Vector2(a.x - b.x, a.z - b.z).length()


## Debug aid (`Enemy.debug_navigation_log`): one line per second with the state of the navigation.
func _log(reason: String, point: Vector3, map: RID) -> void:
	if not _enemy.debug_navigation_log or not OS.is_debug_build():
		return
	var now: int = Time.get_ticks_msec()
	if now < _next_log_msec:
		return
	_next_log_msec = now + 1000
	var path: PackedVector3Array = _agent.get_current_navigation_path()
	print("[Nav] %s | types %s | link at %d (kind %d)" % [_enemy.name, _agent.get_current_navigation_result().path_types, _find_link(path), _link_kind])
	print("[Nav] %s %s | at %s | target %s | map iteration %d, regions %d | path points %d (my index %d) | agent index %d" % [
			_enemy.name, reason, _enemy.global_position.snapped(Vector3(0.1, 0.1, 0.1)),
			point.snapped(Vector3(0.1, 0.1, 0.1)), NavigationServer3D.map_get_iteration_id(map),
			NavigationServer3D.map_get_regions(map).size(), path.size(),
			_index, _agent.get_current_navigation_path_index()])


## Sets the agent's target when it is new, jumped far, or moved enough and the repath interval has passed.
func _update_target(point: Vector3) -> void:
	var now: int = Time.get_ticks_msec()
	var moved: float = _target.distance_to(point)
	var due: bool = float(now - _last_path_msec) >= _ai.nav_repath_interval * 1000.0
	if not _has_target or moved > 2.0 or (moved > _ai.nav_repath_distance and due):
		_target = point
		_has_target = true
		_last_path_msec = now
		_agent.target_position = point
