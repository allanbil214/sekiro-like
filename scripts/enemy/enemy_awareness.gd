class_name EnemyAwareness
extends RefCounted
## The senses of one Enemy (Phase 2, item 7a). Only an Enemy with `use_awareness` on has one; the rest keep
## noticing the player by `aggro_range` alone. The enemy calls `update()` every physics frame while it is in
## Phase.IDLE (nobody noticed yet, or it lost the player); the combat phases are untouched.
##
## A meter from 0 to 1 fills from sight (range, a cone and a clear line to the player) and hearing (the
## player's noise radius, `Player.get_noise_radius()`), and drains when nothing is sensed:
## - UNAWARE (under `suspicious_at`): patrols a loop of waypoints, or stands at its post and scans.
## - SUSPICIOUS: stops, turns toward the cause, then creeps to it. A yellow "?" over its head.
## - ALERT (the meter is full but it cannot see you, or it lost you in combat): goes to the last spot it knew
##   and searches for `search_time` seconds, then goes back to its post. A red "!". It stays alert while it sees
##   you from another level (it cannot reach you: no pathfinding).
## - It spots you (update returns true, the Enemy enters combat) when the meter is full and it sees you within
##   `max_vertical_reach`. An enemy that enters combat shouts: unaware allies nearby turn suspicious or alert.
## Everything it does here moves the enemy by setting `velocity` and `rotation.y`; the Enemy's own loop
## applies gravity and `move_and_slide()`.
## The edge guard (`edge_safe`) is used by the Enemy for its combat movement too.
## All numbers are in EnemyAIData ("Awareness").

enum Level { UNAWARE, SUSPICIOUS, ALERT }

## Seconds between two line-of-sight checks (a ray each), and how far (m) a check is made at all.
const LOS_INTERVAL: float = 0.1
## Seconds between two looks for a body (item 7d).
const CORPSE_INTERVAL: float = 0.2
const LOS_RANGE: float = 22.0
## A patrol waypoint, post or search spot counts as reached this close (m).
const ARRIVE_DISTANCE: float = 0.6
const SYMBOL_POP_TIME: float = 0.18
const SYMBOL_POP_SCALE: float = 1.6
const SUSPICIOUS_COLOR: Color = Color(1.0, 0.85, 0.15)
const ALERT_COLOR: Color = Color(0.95, 0.12, 0.1)

var level: Level = Level.UNAWARE
## 0 to 1. Pinned at 1 while it searches.
var meter: float = 0.0
## Goes up by one every time it spots the player (or is hit): the awareness HUD plays its pop on a change.
var spotted_stamp: int = 0

var _enemy: Enemy
var _ai: EnemyAIData
var _symbol: Label3D
var _symbol_pop: float = 0.0

var _waypoints: Array[Vector3] = []
var _wp_index: int = 0
var _wait_left: float = 0.0
var _home_position: Vector3 = Vector3.ZERO
var _home_yaw: float = 0.0
var _scan_clock: float = 0.0

var _last_known: Vector3 = Vector3.ZERO
var _has_last_known: bool = false
var _investigate: Vector3 = Vector3.ZERO
var _pause_left: float = 0.0
var _search_left: float = 0.0
var _search_arrived: bool = false
var _search_yaw: float = 0.0

var _since_sensed: float = 99.0
var _los_timer: float = 0.0
var _corpse_timer: float = 0.0
var _has_los: bool = false
var _can_see: bool = false
var _stuck: float = 0.0


func _init(enemy: Enemy) -> void:
	_enemy = enemy


## Called from Enemy._ready() once the node is in the tree.
func setup() -> void:
	_ai = _enemy.ai
	_home_position = _enemy.global_position
	_home_yaw = _enemy.rotation.y
	_scan_clock = randf() * TAU
	_los_timer = randf() * LOS_INTERVAL
	if not _enemy.patrol_path.is_empty():
		var path := _enemy.get_node_or_null(_enemy.patrol_path)
		if path == null:
			push_warning("Enemy %s: patrol_path does not point at a node." % _enemy.name)
		else:
			for child: Node in path.get_children():
				var marker := child as Node3D
				if marker != null:
					_waypoints.append(marker.global_position)
	_make_symbol()


## Every physics frame while the enemy is in Phase.IDLE. Returns true when it spots the player.
func update(delta: float, has_target: bool) -> bool:
	_tick_symbol(delta)
	if _ai.notices_corpses and level == Level.UNAWARE and _search_left <= 0.0:
		_look_for_corpses(delta)
	var target := _enemy.get_target()
	var to_target := Vector3.ZERO
	if has_target and target != null and not _is_undetectable(target):
		to_target = target.global_position - _enemy.global_position
		_sense(delta, target, to_target)
	else:
		_can_see = false
		_has_los = false
		_since_sensed += delta
	var reachable := absf(to_target.y) <= _ai.max_vertical_reach
	if _search_left > 0.0:
		_search_left -= delta
		meter = 1.0
		if _search_left <= 0.0:
			_end_search()
	elif _since_sensed > _ai.decay_delay:
		meter = maxf(meter - _ai.meter_decay * delta, 0.0)
	if meter >= 1.0:
		if _can_see and reachable:
			return true
		if _search_left <= 0.0:
			begin_search(_last_known if _has_last_known else _enemy.global_position)
	if _search_left > 0.0:
		_apply_level(Level.ALERT)
		_run_search(delta, target)
	elif meter >= _ai.suspicious_at:
		_apply_level(Level.SUSPICIOUS)
		_run_suspicious(delta)
	else:
		_apply_level(Level.UNAWARE)
		_run_unaware(delta)
	return false


## The enemy entered combat (it spotted the player, or was hit): the "detected" sound, hide the symbol and shout.
func on_spotted() -> void:
	spotted_stamp += 1
	Sfx.play(_enemy.get_tree(), Sfx.Id.DETECTED)
	meter = 1.0
	_search_left = 0.0
	_apply_level(Level.UNAWARE)
	_shout()


## The enemy lost the player in combat (or the meter filled without sight): go to `position` and search.
func begin_search(position: Vector3) -> void:
	_last_known = position
	_has_last_known = true
	_investigate = position
	meter = 1.0
	_search_left = _ai.search_time
	_search_arrived = false
	_since_sensed = 0.0
	_stuck = 0.0
	_apply_level(Level.ALERT)


## Another enemy shouted: `player_position` is where the player is. Within half the shout radius this enemy
## goes alert and searches there, farther it turns suspicious and creeps to it.
func hear_shout(player_position: Vector3, close: bool) -> void:
	_last_known = player_position
	_has_last_known = true
	_investigate = player_position
	meter = maxf(meter, 1.0 if close else 0.75)
	_since_sensed = 0.0
	_pause_left = 0.0


## Back to the start (respawn, the player died): unaware, nothing remembered, the symbol hidden.
func reset() -> void:
	meter = 0.0
	_search_left = 0.0
	_pause_left = 0.0
	_has_last_known = false
	_since_sensed = 99.0
	_can_see = false
	_has_los = false
	_stuck = 0.0
	_wait_left = 0.0
	_apply_level(Level.UNAWARE)
	hide_symbol()


func hide_symbol() -> void:
	if _symbol != null:
		_symbol.visible = false


## False when there is no floor just ahead in `direction` (a flat vector): the enemy should not step there.
func edge_safe(direction: Vector3) -> bool:
	direction.y = 0.0
	if direction.length_squared() < 0.0001 or not _enemy.is_on_floor():
		return true
	var ahead := _enemy.global_position + direction.normalized() * _ai.edge_probe_distance
	var query := PhysicsRayQueryParameters3D.create(
			ahead + Vector3.UP * 0.5, ahead + Vector3.DOWN * _ai.edge_probe_depth, Layers.WORLD)
	query.exclude = [_enemy.get_rid()]
	return not _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func debug_text() -> String:
	return "%s %s %.2f%s" % [_enemy.name, Level.keys()[level], meter, "  SEES" if _can_see else ""]


# --- Senses -------------------------------------------------------------------------------------

## The player's debug switch (F4): nothing is sensed.
func _is_undetectable(target: Node3D) -> bool:
	var player := target as Player
	return player != null and player.debug_undetectable


func _sense(delta: float, target: Node3D, to_target: Vector3) -> void:
	var distance := to_target.length()
	_los_timer -= delta
	if _los_timer <= 0.0:
		_los_timer = LOS_INTERVAL
		_has_los = distance <= LOS_RANGE and _line_is_clear(target)
	var rate := 0.0
	_can_see = false
	var flat := Vector3(to_target.x, 0.0, to_target.z)
	if _has_los and distance <= _ai.sight_range and _in_cone(flat):
		_can_see = true
		rate += _sight_rate(distance, target)
		_remember(target.global_position)
	var player := target as Player
	if player != null:
		var noise := player.get_noise_radius()
		if noise > 0.0:
			var radius := noise * (1.0 if _has_los else _ai.hearing_wall_factor)
			if distance <= radius:
				rate += _ai.hearing_fill_rate * (1.0 - 0.5 * distance / maxf(radius, 0.01))
				_remember(target.global_position)
	if rate > 0.0:
		_since_sensed = 0.0
		meter = minf(meter + rate * delta, 1.0)
	else:
		_since_sensed += delta


func _remember(position: Vector3) -> void:
	_last_known = position
	_has_last_known = true
	_investigate = position


func _in_cone(flat_to_target: Vector3) -> bool:
	if flat_to_target.length_squared() < 0.0001:
		return true
	var forward := -_enemy.global_transform.basis.z
	forward.y = 0.0
	if forward.length_squared() < 0.0001:
		return true
	var angle := forward.normalized().angle_to(flat_to_target.normalized())
	return angle <= deg_to_rad(_ai.sight_degrees * 0.5)


func _sight_rate(distance: float, target: Node3D) -> float:
	var rate := _ai.sight_fill_rate
	if distance <= _ai.sight_close_range:
		rate *= _ai.sight_close_multiplier
	else:
		var t := clampf((distance - _ai.sight_close_range) / maxf(_ai.sight_range - _ai.sight_close_range, 0.01), 0.0, 1.0)
		rate *= lerpf(1.0, _ai.sight_far_multiplier, t)
	var player := target as Player
	if player != null:
		if player.is_crouched:
			rate *= _ai.sight_crouch_multiplier
		elif Vector2(player.velocity.x, player.velocity.z).length() > player.walk_speed * 1.5:
			rate *= _ai.sight_run_multiplier
	return rate


## A ray from the enemy's eye to the player's chest hits only the world (layer 1): the enemies and the player's
## own body are left out, and the invisible walls (layer 6) are not in the mask.
func _line_is_clear(target: Node3D) -> bool:
	var from := _enemy.global_position + Vector3.UP * _ai.sight_eye_height
	var to := target.global_position + Vector3.UP * _ai.sight_target_height
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	var skip: Array[RID] = []
	for node: Node3D in Enemies.all():
		var body := node as CollisionObject3D
		if body != null:
			skip.append(body.get_rid())
	var target_body := target as CollisionObject3D
	if target_body != null:
		skip.append(target_body.get_rid())
	query.exclude = skip
	return _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


func _shout() -> void:
	var target := _enemy.get_target()
	var where := target.global_position if target != null else _enemy.global_position
	for node: Node3D in Enemies.all():
		var other := node as Enemy
		if other == null or other == _enemy or not other.use_awareness:
			continue
		if other.combatant.dead or other.phase != Enemy.Phase.IDLE:
			continue
		var distance := (other.global_position - _enemy.global_position).length()
		if distance <= _ai.shout_radius:
			other.hear_shout(where, distance <= _ai.shout_radius * 0.5)


# --- Corpses (item 7d) ----------------------------------------------------------------------------

## Every CORPSE_INTERVAL: the first undiscovered body inside `corpse_sight_range`, within `max_vertical_reach`
## of height, in the view cone and with a clear line is marked discovered and reacted to.
func _look_for_corpses(delta: float) -> void:
	_corpse_timer -= delta
	if _corpse_timer > 0.0:
		return
	_corpse_timer = CORPSE_INTERVAL
	for node: Node3D in Enemies.all():
		var other := node as Enemy
		if other == null or other == _enemy or not other.is_undiscovered_corpse():
			continue
		var to_body := other.global_position - _enemy.global_position
		if absf(to_body.y) > _ai.max_vertical_reach:
			continue
		var flat := Vector3(to_body.x, 0.0, to_body.z)
		if flat.length() > _ai.corpse_sight_range or not _in_cone(flat):
			continue
		if not _line_to_point_is_clear(other.global_position + Vector3.UP * 0.4):
			continue
		other.mark_corpse_discovered()
		_react_to_corpse(other.global_position)
		return


func _react_to_corpse(position: Vector3) -> void:
	match _ai.corpse_reaction:
		EnemyAIData.CorpseReaction.SUSPICIOUS:
			hear_shout(position, false)
		EnemyAIData.CorpseReaction.ALERT:
			begin_search(position)
		EnemyAIData.CorpseReaction.ALARM:
			begin_search(position)
			for node: Node3D in Enemies.all():
				var other := node as Enemy
				if other == null or other == _enemy or not other.use_awareness:
					continue
				if other.combatant.dead or other.phase != Enemy.Phase.IDLE:
					continue
				if (other.global_position - _enemy.global_position).length() <= _ai.shout_radius:
					other.hear_shout(position, false)


## A ray from the enemy's eye to `point` hits only the world (the same rules as _line_is_clear).
func _line_to_point_is_clear(point: Vector3) -> bool:
	var from := _enemy.global_position + Vector3.UP * _ai.sight_eye_height
	var query := PhysicsRayQueryParameters3D.create(from, point, Layers.WORLD)
	var skip: Array[RID] = []
	for node: Node3D in Enemies.all():
		var body := node as CollisionObject3D
		if body != null:
			skip.append(body.get_rid())
	query.exclude = skip
	return _enemy.get_world_3d().direct_space_state.intersect_ray(query).is_empty()


# --- Behaviors ----------------------------------------------------------------------------------

func _run_unaware(delta: float) -> void:
	if not _waypoints.is_empty():
		_patrol(delta)
	else:
		_post(delta)


func _patrol(delta: float) -> void:
	if _wait_left > 0.0:
		_wait_left -= delta
		_stop(delta)
		return
	if _walk_to(_waypoints[_wp_index], _ai.patrol_speed, delta):
		_wp_index = (_wp_index + 1) % _waypoints.size()
		_wait_left = randf_range(_enemy.patrol_wait.x, _enemy.patrol_wait.y)


## No patrol: walk back to the post if it is away, then stand and sweep the view left and right.
func _post(delta: float) -> void:
	var away := Vector3(_home_position.x - _enemy.global_position.x, 0.0, _home_position.z - _enemy.global_position.z)
	if away.length() > ARRIVE_DISTANCE * 1.5 and _stuck < _ai.stuck_time:
		_walk_to(_home_position, _ai.patrol_speed, delta)
		return
	_stop(delta)
	_scan_clock += delta
	var sweep := sin(_scan_clock * TAU / maxf(_ai.scan_period, 0.1)) * deg_to_rad(_ai.scan_degrees)
	_turn_to_yaw(_home_yaw + sweep, delta, _ai.look_turn_speed * 0.5)


func _run_suspicious(delta: float) -> void:
	if _pause_left > 0.0:
		_pause_left -= delta
		_stop(delta)
		_face_point(_investigate, delta)
		return
	if _walk_to(_investigate, _ai.investigate_speed, delta):
		_face_point(_investigate, delta)


func _run_search(delta: float, target: Node3D) -> void:
	if _can_see and target != null:
		# It sees you but cannot reach you (another level): stay alert, stand and watch.
		_search_left = _ai.search_time
		_stop(delta)
		_face_point(target.global_position, delta)
		return
	if not _search_arrived:
		_search_arrived = _walk_to(_last_known, _ai.search_speed, delta)
		_search_yaw = _enemy.rotation.y
		return
	_stop(delta)
	_scan_clock += delta
	var sweep := sin(_scan_clock * TAU / maxf(_ai.scan_period * 0.6, 0.1)) * deg_to_rad(70.0)
	_turn_to_yaw(_search_yaw + sweep, delta, _ai.look_turn_speed)


func _end_search() -> void:
	_search_left = 0.0
	meter = _ai.suspicious_at * 0.6
	_since_sensed = 0.0
	_stuck = 0.0
	_apply_level(Level.UNAWARE)
	# Resume the patrol at the nearest waypoint (a post sends it home by itself).
	var best := 0
	var best_distance := INF
	for i in range(_waypoints.size()):
		var d := _waypoints[i].distance_squared_to(_enemy.global_position)
		if d < best_distance:
			best_distance = d
			best = i
	_wp_index = best


## Walk toward a point on the flat at `speed`. Returns true when it got there, when the point is on another
## level (it only stands and looks), or when it made no progress for `stuck_time`.
func _walk_to(point: Vector3, speed: float, delta: float) -> bool:
	var to := point - _enemy.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var distance := flat.length()
	if distance <= ARRIVE_DISTANCE or absf(to.y) > _ai.max_vertical_reach:
		_stop(delta)
		_stuck = 0.0
		return true
	var direction := flat / distance
	var wanted := direction * speed
	if not edge_safe(direction):
		wanted = Vector3.ZERO
	_steer(wanted, delta)
	_turn_to_yaw(atan2(-direction.x, -direction.z), delta, _ai.turn_speed * 0.5)
	var moving := Vector2(_enemy.velocity.x, _enemy.velocity.z).length()
	if moving < speed * 0.25:
		_stuck += delta
		if _stuck >= _ai.stuck_time:
			_stuck = 0.0
			_stop(delta)
			return true
	else:
		_stuck = 0.0
	return false


func _steer(wanted: Vector3, delta: float) -> void:
	_enemy.velocity.x = move_toward(_enemy.velocity.x, wanted.x, _ai.acceleration * delta)
	_enemy.velocity.z = move_toward(_enemy.velocity.z, wanted.z, _ai.acceleration * delta)


func _stop(delta: float) -> void:
	_steer(Vector3.ZERO, delta)


func _face_point(point: Vector3, delta: float) -> void:
	var to := point - _enemy.global_position
	to.y = 0.0
	if to.length_squared() > 0.0001:
		_turn_to_yaw(atan2(-to.x, -to.z), delta, _ai.look_turn_speed)


func _turn_to_yaw(yaw: float, delta: float, speed: float) -> void:
	_enemy.rotation.y = lerp_angle(_enemy.rotation.y, yaw, 1.0 - exp(-speed * delta))


# --- The "?" and "!" ----------------------------------------------------------------------------

func _make_symbol() -> void:
	_symbol = Label3D.new()
	_symbol.name = "AwarenessSymbol"
	_symbol.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_symbol.no_depth_test = true
	_symbol.font_size = _ai.symbol_font_size
	_symbol.pixel_size = _ai.symbol_pixel_size
	_symbol.outline_size = 40
	_symbol.outline_modulate = Color(0.0, 0.0, 0.0, 1.0)
	_symbol.render_priority = 10
	_symbol.outline_render_priority = 9
	_symbol.position = Vector3(0.0, _ai.symbol_height, 0.0)
	_symbol.visible = false
	_enemy.add_child(_symbol)


func _apply_level(new_level: Level) -> void:
	if new_level == level:
		return
	var raised := new_level > level
	level = new_level
	if _enemy.debug_log and OS.is_debug_build():
		print("[Awareness] %s -> %s (meter %.2f)" % [_enemy.name, Level.keys()[level], meter])
	if level == Level.SUSPICIOUS:
		_pause_left = _ai.suspicious_pause
	if _symbol == null:
		return
	if level == Level.UNAWARE:
		_symbol.visible = false
		return
	_symbol.text = "?" if level == Level.SUSPICIOUS else "!"
	_symbol.modulate = SUSPICIOUS_COLOR if level == Level.SUSPICIOUS else ALERT_COLOR
	_symbol.visible = true
	if raised:
		_symbol_pop = 1.0
		_symbol.scale = Vector3.ONE * SYMBOL_POP_SCALE


func _tick_symbol(delta: float) -> void:
	if _symbol == null or _symbol_pop <= 0.0:
		return
	_symbol_pop = maxf(_symbol_pop - delta / SYMBOL_POP_TIME, 0.0)
	_symbol.scale = Vector3.ONE * lerpf(1.0, SYMBOL_POP_SCALE, _symbol_pop)
