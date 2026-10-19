class_name EnemyNavigation
extends RefCounted
## Phase 2 item 12a: navmesh pathing for one Enemy (the enemy makes it in _ready() when `use_navigation` is on).
##
## It wraps the enemy's `NavigationAgent` child node: `direction_to(point)` returns the flat unit direction of
## the next step on the path to the point, and the caller (EnemyAwareness._walk_to, Enemy._update_chase) steers
## with it exactly as it did with the straight line. Everything else stays with the callers: the edge guard, the
## stuck timer, the arrival distance and the vertical reach. The path index is kept here, not read from the
## agent. It only walks: a navmesh has no climbing, so a
## target on another level ends at the closest point of the mesh (the enemy stands there; jump, drop and climb
## links are item 12b).
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
	return true


## The flat unit direction toward the next path point, or zero when there is nothing to follow.
func direction_to(point: Vector3) -> Vector3:
	if _agent == null:
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
	while _index < path.size() and _flat_distance(here, path[_index]) <= reach:
		_index += 1
	if _index >= path.size():
		_log("PATH DONE", point, map)
		return Vector3.ZERO # the end of the path (the target, or the closest point of the mesh to it)
	var flat := Vector3(path[_index].x - here.x, 0.0, path[_index].z - here.z)
	_log("WALKING", point, map)
	return flat.normalized()


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
