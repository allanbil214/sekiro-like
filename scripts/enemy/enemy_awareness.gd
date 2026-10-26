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
## The body routine of the guard that found a body (item 7e). GO to CHECK, ROAM and RETURN it investigates (it
## shows "?" or "!"); RESPECT_GO to PLACE it is calm again and respects the body.
## WAKE_GO and WAKE (item 10) are the milder routine for an unconscious body: walk to it, pause, wake it.
enum Tend { NONE, GO, CHECK, ROAM, RETURN, RESPECT_GO, LIFT, CARRY, PLACE, WAKE_GO, WAKE }
## Half the width (m) of a lying body, and how far (m) behind the laid body the carrier stands.
const BODY_HALF_WIDTH: float = 0.45
const CARRIER_BACK_OFF: float = 0.8
const ROAM_CLEARANCE: float = 0.9
## Rays fanned out from a body to find the nearest wall.
const WALL_RAYS: int = 32

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

## Checking a spot (item 11d): GO walks to it, CHECK stands there and looks around until the time is up.
enum Spot { NONE, GO, CHECK }
## A new sound this far (m) from the spot being checked moves the spot (the guard walks there).
const SPOT_RETARGET: float = 1.5

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
var _spot_stage: Spot = Spot.NONE
var _spot: Vector3 = Vector3.ZERO
var _spot_timer: float = 0.0
var _spot_yaw: float = 0.0
## Thrown-item noises heard during the current check (`EnemyAIData.spot_alert_count` makes it furious).
var _spot_noises: int = 0

var _since_sensed: float = 99.0
var _los_timer: float = 0.0
var _corpse_timer: float = 0.0
var _has_los: bool = false
var _can_see: bool = false
## Item 22: where the head points (radians, positive = up), where it wants to point (set by `_face_point()` each
## frame the guard looks at something) and whether it was set since the last `tick_head()`.
var _head_pitch: float = 0.0
var _look_pitch: float = 0.0
var _look_pitch_set: bool = false
## Item 22 debug: the two sight cones drawn on every guard with awareness (F3 in a debug build, see `Player`).
static var show_debug_cones: bool = false
var _cone_mesh: MeshInstance3D
var _stuck: float = 0.0

var _tend: Tend = Tend.NONE
var _tend_body: Enemy
var _tend_timer: float = 0.0
## Item 15d: where the tended body lay last (kept while the body is valid, used when it vanishes).
var _tend_spot: Vector3 = Vector3.ZERO
var _check_angle: float = 0.0
var _check_dir: float = 1.0
var _check_left: float = 0.0
var _carrying: bool = false
## Item 15d: the different dead bodies this guard has found (instance ids), kept for the rest of the level.
var _found_bodies: Dictionary = {}
## Item 15d: the body of the player's carry this guard already counted as a find (once per carry).
var _carry_counted: Enemy
var _has_wall: bool = false
var _wall_spot: Vector3 = Vector3.ZERO
var _wall_body: Vector3 = Vector3.ZERO
var _wall_yaw: float = 0.0
var _roam_points: Array[Vector3] = []
var _roam_index: int = 0
var _roam_timer: float = -1.0
var _roam_yaw: float = 0.0


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
		_check_seen_carry(target)
	else:
		_can_see = false
		_has_los = false
		_since_sensed += delta
	var reachable := _enemy.can_reach_height(to_target.y)
	if _spot_stage != Spot.NONE:
		meter = maxf(meter, _ai.suspicious_at)
	# The player (or a shout) made it properly suspicious while it investigated a body: it will respect the body later.
	if _investigating() and meter >= _ai.suspicious_at:
		_set_tend(Tend.RESPECT_GO, "made suspicious while investigating")
	if _search_left > 0.0:
		_search_left -= delta
		meter = 1.0
		if _search_left <= 0.0:
			_end_search()
	elif _since_sensed > _ai.decay_delay and _spot_stage == Spot.NONE:
		meter = maxf(meter - _ai.meter_decay * delta, 0.0)
	if meter >= 1.0:
		if _can_see and reachable:
			return true
		if _search_left <= 0.0:
			begin_search(_last_known if _has_last_known else _enemy.global_position)
	if _search_left > 0.0:
		_on_distracted()
		_apply_level(Level.ALERT)
		_run_search(delta, target)
	elif _investigating():
		_apply_level(_investigation_level())
		_run_investigation(delta)
	elif meter >= _ai.suspicious_at or _spot_stage != Spot.NONE:
		_on_distracted()
		_apply_level(Level.SUSPICIOUS)
		_run_suspicious(delta)
	else:
		_spot_noises = 0
		_apply_level(Level.UNAWARE)
		if _tend == Tend.WAKE_GO or _tend == Tend.WAKE:
			_run_wake(delta)
		elif _tend != Tend.NONE:
			_run_respect(delta)
		else:
			_run_unaware(delta)
	return false


## The enemy entered combat (it spotted the player, or was hit): the "detected" sound, hide the symbol and shout.
func on_spotted() -> void:
	spotted_stamp += 1
	Sfx.play(_enemy.get_tree(), Sfx.Id.DETECTED)
	meter = 1.0
	_search_left = 0.0
	_clear_spot()
	# In combat: a carried body is dropped; a pending routine resumes at the respect once it is calm again.
	if _carrying:
		_drop_body()
	if _tend != Tend.NONE:
		_set_tend(Tend.RESPECT_GO if _body_ok() else Tend.NONE, "combat, resume at the respect")
	_apply_level(Level.UNAWARE)
	_shout()


## The enemy lost the player in combat (or the meter filled without sight): go to `position` and search.
func begin_search(position: Vector3) -> void:
	_last_known = position
	_has_last_known = true
	_investigate = position
	_clear_spot()
	meter = 1.0
	_search_left = _search_cap()
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


## Phase 2 item 21: another enemy that sees the player but cannot reach it calls for help from `caller_position`;
## `player_position` is where the player is. Heard inside `radius` (less through a wall): within half of it this
## enemy goes alert and searches there, farther it turns suspicious and creeps to it (like a shout).
func hear_call(caller_position: Vector3, player_position: Vector3, radius: float) -> void:
	var heard := radius
	if not _line_to_point_is_clear(caller_position + Vector3.UP * 0.3):
		heard *= _ai.hearing_wall_factor
	var distance := _enemy.global_position.distance_to(caller_position)
	if distance > heard:
		return
	hear_shout(player_position, distance <= heard * 0.5)


## Phase 2 item 11a: something thrown landed at `point` and made `radius` m of noise (`Throwable`). Within hearing
## (less through a wall) the enemy turns suspicious and goes to look, like a far shout; it does not spot anyone.
func hear_noise_at(point: Vector3, radius: float) -> void:
	var heard := radius
	if not _line_to_point_is_clear(point + Vector3.UP * 0.3):
		heard *= _ai.hearing_wall_factor
	if _enemy.global_position.distance_to(point) > heard:
		return
	_spot_noises += 1
	if _ai.spot_alert_count > 0 and _spot_noises >= _ai.spot_alert_count:
		# Noise after noise: furious. It goes alert and searches the spot, but it still knows nothing about the player.
		begin_search(point)
		return
	_last_known = point
	_has_last_known = true
	_investigate = point
	meter = maxf(meter, _ai.suspicious_at)
	_since_sensed = 0.0
	_pause_left = 0.0


## Phase 2 item 20: a thrown item (or body) hit this enemy while it had not noticed the player. It spots no one and no
## shout goes out: it turns toward where the shot came from (the usual suspicious pause) and goes to look at a guess
## of that place: `origin`, where the thrower stood, off by up to `EnemyAIData.shot_guess_error` m. Repeated hits
## count like repeated noises: `spot_alert_count` of them make it furious (an alert search at the guess), still
## without knowing where the player is. If it sees the player on the way, the normal sight rules apply.
func investigate_shot(origin: Vector3) -> void:
	var guess := origin
	if _ai.shot_guess_error > 0.0:
		var angle := randf() * TAU
		var distance := _ai.shot_guess_error * sqrt(randf())
		guess += Vector3(cos(angle), 0.0, sin(angle)) * distance
	_spot_noises += 1
	if _ai.spot_alert_count > 0 and _spot_noises >= _ai.spot_alert_count:
		begin_search(guess)
		return
	_last_known = guess
	_has_last_known = true
	_investigate = guess
	meter = maxf(meter, _ai.suspicious_at)
	_since_sensed = 0.0
	_pause_left = 0.0


## Back to the start (respawn, the player died): unaware, nothing remembered, the symbol hidden.
func reset() -> void:
	_set_tend(Tend.NONE, "reset")
	_clear_spot()
	if is_instance_valid(_tend_body):
		_tend_body.held_by_guard = false
	_tend_body = null
	_carrying = false
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
	var tending := "  TEND:%s" % Tend.keys()[_tend] if _tend != Tend.NONE else ""
	return "%s %s %.2f%s%s  pitch %+d" % [_enemy.name, Level.keys()[level], meter, "  SEES" if _can_see else "", tending, roundi(rad_to_deg(_head_pitch))]


## Item 22 debug (a debug build, F3): the sideways cone (flat, at eye height; green unaware, yellow suspicious, red
## alert, grey in combat) and the up-and-down cone (cyan, around the head's pitch), as lines out to `sight_range`,
## and a line to the player (green when it sees the player, dark red when not). Called every frame by the Enemy.
func draw_debug_cones() -> void:
	if not OS.is_debug_build():
		return
	var shown := show_debug_cones and not _enemy.combatant.dead
	if _cone_mesh == null:
		if not shown:
			return
		_cone_mesh = MeshInstance3D.new()
		_cone_mesh.name = "SightConesDebug"
		_cone_mesh.mesh = ImmediateMesh.new()
		_cone_mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var material := StandardMaterial3D.new()
		material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		material.vertex_color_use_as_albedo = true
		material.no_depth_test = true
		material.render_priority = 5
		_cone_mesh.material_override = material
		_enemy.add_child(_cone_mesh)
	_cone_mesh.visible = shown
	if not shown:
		return
	var mesh := _cone_mesh.mesh as ImmediateMesh
	mesh.clear_surfaces()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	var eye := Vector3(0.0, _ai.sight_eye_height, 0.0)
	var reach := _ai.sight_range
	var side_color := Color(0.6, 0.6, 0.6)
	if _enemy.phase == Enemy.Phase.IDLE:
		match level:
			Level.UNAWARE:
				side_color = Color(0.2, 1.0, 0.3)
			Level.SUSPICIOUS:
				side_color = Color(1.0, 0.9, 0.2)
			Level.ALERT:
				side_color = Color(1.0, 0.25, 0.2)
	var half := deg_to_rad(_ai.sight_degrees * 0.5)
	_debug_fan(mesh, eye, reach, -half, half, false, 0.0, side_color)
	if _ai.sight_vertical_degrees < 360.0:
		var vertical_half := deg_to_rad(_ai.sight_vertical_degrees * 0.5)
		_debug_fan(mesh, eye, reach, -vertical_half, vertical_half, true, _head_pitch, Color(0.2, 0.85, 1.0))
	var target := _enemy.get_target()
	if target != null:
		var chest := _enemy.to_local(target.global_position + Vector3.UP * _ai.sight_target_height)
		var seen_color := Color(0.3, 1.0, 0.3) if _can_see else Color(0.5, 0.1, 0.1)
		mesh.surface_set_color(seen_color)
		mesh.surface_add_vertex(eye)
		mesh.surface_set_color(seen_color)
		mesh.surface_add_vertex(chest)
	mesh.surface_end()


## One fan of lines in the enemy's local space: two edges and an arc. `vertical` false = flat (yaw from -half to
## +half), true = in the forward-up plane (pitch from `tilt - half`... `tilt + half`).
func _debug_fan(mesh: ImmediateMesh, eye: Vector3, reach: float, from_angle: float, to_angle: float, vertical: bool, tilt: float, color: Color) -> void:
	const SEGMENTS: int = 24
	var previous := Vector3.ZERO
	for i in SEGMENTS + 1:
		var angle := lerpf(from_angle, to_angle, float(i) / float(SEGMENTS))
		var direction: Vector3
		if vertical:
			direction = Vector3(0.0, sin(tilt + angle), -cos(tilt + angle))
		else:
			direction = Vector3(sin(angle), 0.0, -cos(angle))
		var point := eye + direction * reach
		if i == 0 or i == SEGMENTS:
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(eye)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(point)
		if i > 0:
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(previous)
			mesh.surface_set_color(color)
			mesh.surface_add_vertex(point)
		previous = point


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
	if _has_los and distance <= _ai.sight_range and _in_cone(flat) and _in_vertical_cone(target):
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


## Item 22: true when the player's chest is inside the up-and-down view around the head's pitch.
func _in_vertical_cone(target: Node3D) -> bool:
	if _ai.sight_vertical_degrees >= 360.0:
		return true
	var to_chest := (target.global_position + Vector3.UP * _ai.sight_target_height) \
			- (_enemy.global_position + Vector3.UP * _ai.sight_eye_height)
	var angle := atan2(to_chest.y, Vector2(to_chest.x, to_chest.z).length())
	return absf(angle - _head_pitch) <= deg_to_rad(_ai.sight_vertical_degrees * 0.5)


## Item 22: every physics frame (any phase), before the senses: the head eases toward the pitch `_face_point()` asked
## for in the last frame, or level when the guard is not looking at anything.
func tick_head(delta: float) -> void:
	var wanted := _look_pitch if _look_pitch_set else 0.0
	_look_pitch_set = false
	_head_pitch = lerpf(_head_pitch, wanted, 1.0 - exp(-_ai.head_pitch_speed * delta))
	_enemy.set_head_pitch(_head_pitch)


## The pitch (radians, clamped to the head's limit) from the eye toward `point`.
func _pitch_to(point: Vector3) -> float:
	var to := point - (_enemy.global_position + Vector3.UP * _ai.sight_eye_height)
	var limit := deg_to_rad(_ai.head_pitch_max_degrees)
	return clampf(atan2(to.y, Vector2(to.x, to.z).length()), -limit, limit)


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
		# Item 9: pressed against a wall it is harder to see (on top of crouching).
		if player.is_wall_hugging() and not player.is_peeking_up():
			rate *= player.wall_hug_sight_multiplier
		# Item 15d: carrying a body is easier to see.
		if player.is_carrying():
			rate *= _ai.carry_sight_multiplier
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
		if other == null or other == _enemy or not other.is_undiscovered_body():
			continue
		var to_body := other.global_position - _enemy.global_position
		if absf(to_body.y) > _ai.max_vertical_reach:
			continue
		var flat := Vector3(to_body.x, 0.0, to_body.z)
		if flat.length() > _ai.corpse_sight_range or not _in_cone(flat):
			continue
		if other.is_hidden_in_cover():
			continue
		if not _line_to_point_is_clear(other.global_position + Vector3.UP * 0.4):
			continue
		other.mark_corpse_discovered()
		_react_to_corpse(other)
		return


## Item 15d: a guard that sees the player carry a dead body counts it as a find (once per carry): it turns
## suspicious about the player, or raises the alarm when this is the body's or the guard's third.
func _check_seen_carry(target: Node3D) -> void:
	var player := target as Player
	if player == null or not player.is_carrying():
		_carry_counted = null
		return
	if not _can_see or level != Level.UNAWARE or _search_left > 0.0 or not _ai.notices_corpses:
		return
	var body := player.carried_body
	if body == null or body == _carry_counted or not body.is_corpse():
		return
	_carry_counted = body
	if _register_find(body):
		_raise_alarm(player.global_position, body)
	else:
		hear_shout(player.global_position, false)


## Item 15d: counts a find of a dead body; true when it reaches an alarm rule.
func _register_find(body: Enemy) -> bool:
	if not body.is_corpse():
		return false
	body.times_found += 1
	_found_bodies[body.get_instance_id()] = true
	if _ai.corpse_finds_to_alarm > 0 and body.times_found >= _ai.corpse_finds_to_alarm:
		return true
	return _ai.bodies_found_to_alarm > 0 and _found_bodies.size() >= _ai.bodies_found_to_alarm


## Item 15d: full alert about `position`: this guard searches there and the calm allies in range go alert too.
func _raise_alarm(position: Vector3, body: Enemy) -> void:
	if _carrying:
		_drop_body()
	_tend_body = body
	_set_tend(Tend.RESPECT_GO if _body_ok() else Tend.NONE, "alarm")
	_stuck = 0.0
	begin_search(position)
	for node: Node3D in Enemies.all():
		var other := node as Enemy
		if other == null or other == _enemy or not other.use_awareness:
			continue
		if other.combatant.dead or other.phase != Enemy.Phase.IDLE:
			continue
		if (other.global_position - _enemy.global_position).length() <= _ai.shout_radius:
			other.hear_shout(position, true)


func _react_to_corpse(body: Enemy) -> void:
	var position := body.global_position
	if body.is_unconscious():
		# Item 10: no alarm for a sleeper, the guard goes and wakes him.
		if _carrying:
			_drop_body()
		_tend_body = body
		_set_tend(Tend.WAKE_GO, "found an unconscious body")
		_stuck = 0.0
		return
	if _register_find(body):
		_raise_alarm(position, body)
		return
	if _ai.tends_corpses:
		# Item 7e: the whole routine, in the style of `corpse_reaction`.
		if _carrying:
			_drop_body()
		_tend_body = body
		_set_tend(Tend.GO, "found a body")
		_stuck = 0.0
		if _ai.corpse_reaction == EnemyAIData.CorpseReaction.ALARM:
			_alert_allies(position)
		return
	match _ai.corpse_reaction:
		EnemyAIData.CorpseReaction.SUSPICIOUS:
			hear_shout(position, false)
		EnemyAIData.CorpseReaction.ALERT:
			begin_search(position)
		EnemyAIData.CorpseReaction.ALARM:
			begin_search(position)
			_alert_allies(position)


## Allies inside `shout_radius` that are calm turn suspicious about `position`.
func _alert_allies(position: Vector3) -> void:
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


# --- The body routine (item 7e) ---------------------------------------------------------------------
# Go to the body, check it on an arc, roam for the culprit, come back (these four show "?" or "!"), then, calm
# again: lift it, carry it to the nearest wall, lay it down. Being made suspicious by the player or a shout
# during the first four skips ahead to RESPECT_GO; combat or anything that makes the guard suspicious or alert
# drops a carried body and resumes at RESPECT_GO once it is calm. A body that is gone, or no wall in range,
# ends the routine.

## Every change of the routine's stage goes through here, so `debug_log` shows why it ran or gave up.
func _set_tend(stage: Tend, why: String = "") -> void:
	if stage != _tend and _enemy.debug_log and OS.is_debug_build():
		print("[Awareness] %s tend %s -> %s %s" % [_enemy.name, Tend.keys()[_tend], Tend.keys()[stage], why])
	_tend = stage


## Item 15d: the body this guard was tending is gone (the player picked it up). A guard that sees the spot
## empty searches it; one that does not stays suspicious about the spot and looks around. No alarm either way.
func _on_body_gone() -> void:
	var spot := _tend_spot
	_tend_body = null
	_set_tend(Tend.NONE, "body gone")
	if _can_see_spot(spot):
		begin_search(spot)
	else:
		hear_shout(spot, false)


## True when `point` is in this guard's view: in range, in the cone and with a clear line.
func _can_see_spot(point: Vector3) -> bool:
	var flat := point - _enemy.global_position
	flat.y = 0.0
	if flat.length() > _ai.corpse_sight_range or not _in_cone(flat):
		return false
	return _line_to_point_is_clear(point + Vector3.UP * 0.4)


func _investigating() -> bool:
	return _tend >= Tend.GO and _tend <= Tend.RETURN


func _investigation_level() -> Level:
	return Level.SUSPICIOUS if _ai.corpse_reaction == EnemyAIData.CorpseReaction.SUSPICIOUS else Level.ALERT


func _style_speed() -> float:
	return _ai.investigate_speed if _ai.corpse_reaction == EnemyAIData.CorpseReaction.SUSPICIOUS else _ai.search_speed


func _body_ok() -> bool:
	return is_instance_valid(_tend_body) and _tend_body.is_corpse() and not _tend_body.is_carried()


func _flat_distance_to(point: Vector3) -> float:
	var to := point - _enemy.global_position
	to.y = 0.0
	return to.length()


## Suspicious or alert for another reason: put a carried body down and respect it later.
func _on_distracted() -> void:
	if _tend == Tend.WAKE_GO or _tend == Tend.WAKE:
		_set_tend(Tend.NONE, "distracted, forget the sleeper")
		_tend_body = null
	if _carrying:
		_drop_body()
	if _investigating() or _tend >= Tend.LIFT:
		_set_tend(Tend.RESPECT_GO, "distracted, resume at the respect")


## A carried body is put down where the guard stands (it died, or something made it drop everything).
func drop_carried() -> void:
	if _carrying:
		_drop_body()


func _run_investigation(delta: float) -> void:
	if not _body_ok():
		_on_body_gone()
		return
	var body_pos := _tend_body.global_position
	_tend_spot = body_pos
	match _tend:
		Tend.GO:
			if _flat_distance_to(body_pos) <= _ai.corpse_check_radius + 0.3 \
					or _walk_to(body_pos, _style_speed(), delta):
				_begin_check(body_pos)
		Tend.CHECK:
			_run_check(body_pos, delta)
		Tend.ROAM:
			if _roam_step(_style_speed(), delta):
				_set_tend(Tend.RETURN, "")
		Tend.RETURN:
			if _flat_distance_to(body_pos) <= _ai.corpse_pickup_distance \
					or _walk_to(body_pos, _style_speed(), delta):
				_begin_lift()


## An unconscious body (item 10): walk to it, pause, wake it. It wakes where it lies, and both guards are then
## suspicious about the spot (no alarm), then the guard goes back to its patrol.
func _run_wake(delta: float) -> void:
	if not is_instance_valid(_tend_body) or not _tend_body.is_unconscious() or _tend_body.is_carried():
		_set_tend(Tend.NONE, "the sleeper is gone")
		_tend_body = null
		return
	var body_pos := _tend_body.global_position
	match _tend:
		Tend.WAKE_GO:
			if _flat_distance_to(body_pos) <= _ai.corpse_pickup_distance \
					or _walk_to(body_pos, _ai.patrol_speed, delta):
				_tend_timer = 0.0
				_set_tend(Tend.WAKE, "")
		Tend.WAKE:
			_stop(delta)
			_face_point(body_pos, delta)
			_tend_timer += delta
			if _tend_timer >= _ai.wake_pause:
				var here := _enemy.global_position
				_tend_body.wake_up(here, false)
				_set_tend(Tend.NONE, "woke the sleeper")
				_tend_body = null
				hear_shout(here, false)


## Calm again: walk to the body (when it was interrupted), lift it, carry it to the wall, lay it down.
func _run_respect(delta: float) -> void:
	if not _body_ok():
		_on_body_gone()
		return
	var body_pos := _tend_body.global_position
	_tend_spot = body_pos
	match _tend:
		Tend.RESPECT_GO:
			if _flat_distance_to(body_pos) <= _ai.corpse_pickup_distance \
					or _walk_to(body_pos, _ai.patrol_speed, delta):
				_begin_lift()
		Tend.LIFT:
			_stop(delta)
			_face_point(body_pos, delta)
			_tend_timer += delta
			if _tend_timer >= _ai.corpse_pickup_pause:
				_carrying = true
				_tend_body.held_by_guard = true
				_set_tend(Tend.CARRY, "")
				_hold_body()
		Tend.CARRY:
			_hold_body()
			if _walk_to(_wall_spot, _ai.corpse_carry_speed, delta):
				_put_down(true)
				_set_tend(Tend.PLACE, "")
				_tend_timer = 0.0
		Tend.PLACE:
			_stop(delta)
			_tend_timer += delta
			if _tend_timer >= _ai.corpse_place_pause:
				_set_tend(Tend.NONE, "done")
				_tend_body = null
				_resume_patrol()


func _begin_check(body_pos: Vector3) -> void:
	if _flat_distance_to(body_pos) > _ai.corpse_check_radius + 3.0:
		_set_tend(Tend.NONE, "blocked, could not get near the body")  # it could not get close (blocked): give the body up
		return
	var from_body := _enemy.global_position - body_pos
	from_body.y = 0.0
	_check_angle = atan2(from_body.z, from_body.x) if from_body.length_squared() > 0.01 else 0.0
	_check_dir = 1.0 if randf() < 0.5 else -1.0
	_check_left = deg_to_rad(_ai.corpse_check_arc_degrees)
	_tend_timer = 0.0
	_stuck = 0.0
	_set_tend(Tend.CHECK, "")


## Walk an arc around the body, always facing it (the target point moves ahead along the ring), then pause.
func _run_check(body_pos: Vector3, delta: float) -> void:
	if _check_left > 0.0:
		var radius := maxf(_ai.corpse_check_radius, 0.5)
		var target := body_pos + Vector3(cos(_check_angle), 0.0, sin(_check_angle)) * radius
		target.y = _enemy.global_position.y
		if _flat_distance_to(target) <= 1.0:
			var step := _ai.corpse_check_speed / radius * delta
			_check_angle += _check_dir * step
			_check_left -= step
		if _walk_facing(target, _ai.corpse_check_speed, body_pos, delta):
			_check_left = 0.0  # blocked: that is enough checking
		return
	_stop(delta)
	_face_point(body_pos, delta)
	_tend_timer += delta
	if _tend_timer >= _ai.corpse_check_pause:
		_roam_begin(body_pos, _ai.corpse_roam_radius)
		_set_tend(Tend.ROAM, "")


func _begin_lift() -> void:
	if not _body_ok() or _flat_distance_to(_tend_body.global_position) > _ai.corpse_pickup_distance * 2.5:
		_set_tend(Tend.NONE, "could not reach the body to lift it")  # it could not get to the body
		return
	if not _find_wall_spot():
		_set_tend(Tend.NONE, "no wall within %d m, leaves the body" % int(_ai.corpse_wall_search))  # no wall in range: it leaves the body where it lies
		return
	_set_tend(Tend.LIFT, "")
	_tend_timer = 0.0


## Fan WALL_RAYS rays at chest height from the body; the nearest nearly vertical hit is the wall. The body is laid
## `corpse_wall_gap` from it along the wall, and the carrier stands a little farther out.
func _find_wall_spot() -> bool:
	_has_wall = false
	var origin := _tend_body.global_position + Vector3.UP * ROAM_CLEARANCE
	var space := _enemy.get_world_3d().direct_space_state
	var rids := _enemy_rids()
	var best := INF
	for i in range(WALL_RAYS):
		var angle := TAU * float(i) / float(WALL_RAYS)
		var direction := Vector3(cos(angle), 0.0, sin(angle))
		var query := PhysicsRayQueryParameters3D.create(
				origin, origin + direction * _ai.corpse_wall_search, Layers.WORLD)
		query.exclude = rids
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit.normal
		if absf(normal.y) > 0.35:
			continue
		var point: Vector3 = hit.position
		var distance := origin.distance_to(point)
		if distance >= best:
			continue
		best = distance
		var out := Vector3(normal.x, 0.0, normal.z).normalized()
		_wall_body = Vector3(point.x, _tend_body.global_position.y, point.z) + out * _ai.corpse_wall_gap
		_wall_spot = _wall_body + out * CARRIER_BACK_OFF
		var along := Vector3(-out.z, 0.0, out.x)
		_wall_yaw = atan2(along.x, along.z)
		_has_wall = true
	return _has_wall


## The body hangs over the carrier's right shoulder (a placeholder for a carry animation).
func _hold_body() -> void:
	if not _body_ok():
		return
	var yaw := _enemy.global_rotation.y
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var middle := _enemy.global_position + right * _ai.corpse_carry_shoulder + Vector3.UP * _ai.corpse_carry_height
	var rot := Vector3(deg_to_rad(_ai.corpse_carry_tilt_degrees), yaw, 0.0)
	_tend_body.global_position = _tend_body.lying_root_for(middle, Basis.from_euler(rot))
	_tend_body.global_rotation = rot


## Lay the body down: along the wall when the carrier got there, otherwise in front of it.
func _put_down(at_wall: bool) -> void:
	_carrying = false
	if is_instance_valid(_tend_body):
		_tend_body.held_by_guard = false
	if not _body_ok():
		return
	if at_wall and _has_wall and _flat_distance_to(_wall_spot) <= 1.5:
		_tend_body.global_position = Vector3(_wall_body.x, _enemy.global_position.y, _wall_body.z)
		_tend_body.global_rotation = Vector3(0.0, _wall_yaw, 0.0)
		return
	var forward := -_enemy.global_transform.basis.z
	_tend_body.global_position = _enemy.global_position + forward * 0.7
	_tend_body.global_rotation = Vector3(0.0, _enemy.rotation.y + PI * 0.5, 0.0)


func _drop_body() -> void:
	_put_down(false)


# --- Roaming (the body routine and the alert search) ----------------------------------------------------

## `roam_points` points evenly around a ring of `radius` from `center`, the first at the guard's own angle.
## A point behind a wall is pulled back in front of it, and one with no floor nearby is left out.
func _roam_begin(center: Vector3, radius: float) -> void:
	_roam_points.clear()
	_roam_index = 0
	_roam_timer = -1.0
	_stuck = 0.0
	var from_center := _enemy.global_position - center
	from_center.y = 0.0
	var start := atan2(from_center.z, from_center.x) if from_center.length_squared() > 0.01 else 0.0
	var count := maxi(_ai.roam_points, 1)
	for i in range(count):
		var angle := start + TAU * float(i) / float(count)
		var point := center + Vector3(cos(angle), 0.0, sin(angle)) * radius
		point = _clamp_to_wall(center, point)
		if _has_floor_near(point, center.y):
			_roam_points.append(point)


## Visit the next point, pause there and sweep the view. True once every point has been visited.
func _roam_step(speed: float, delta: float) -> bool:
	if _roam_index >= _roam_points.size():
		return true
	if _roam_timer < 0.0:
		if _walk_to(_roam_points[_roam_index], speed, delta):
			_roam_timer = 0.0
			_roam_yaw = _enemy.rotation.y
		return false
	_stop(delta)
	_roam_timer += delta
	var phase := _roam_timer / maxf(_ai.roam_pause, 0.1)
	_turn_to_yaw(_roam_yaw + sin(phase * TAU) * deg_to_rad(_ai.roam_sweep_degrees), delta, _ai.look_turn_speed)
	if _roam_timer >= _ai.roam_pause:
		_roam_index += 1
		_roam_timer = -1.0
	return false


func _clamp_to_wall(center: Vector3, point: Vector3) -> Vector3:
	var from := center + Vector3.UP * ROAM_CLEARANCE
	var to := Vector3(point.x, center.y + ROAM_CLEARANCE, point.z)
	var query := PhysicsRayQueryParameters3D.create(from, to, Layers.WORLD)
	query.exclude = _enemy_rids()
	var hit := _enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return point
	var hit_point: Vector3 = hit.position
	var back := from - hit_point
	back.y = 0.0
	if back.length_squared() < 0.0001:
		return Vector3(center.x, point.y, center.z)
	return Vector3(hit_point.x, point.y, hit_point.z) + back.normalized() * ROAM_CLEARANCE


func _has_floor_near(point: Vector3, y: float) -> bool:
	var query := PhysicsRayQueryParameters3D.create(
			point + Vector3.UP * 1.0, point + Vector3.DOWN * 2.0, Layers.WORLD)
	query.exclude = _enemy_rids()
	var hit := _enemy.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return false
	var hit_point: Vector3 = hit.position
	return absf(hit_point.y - y) <= 1.0


func _enemy_rids() -> Array[RID]:
	var rids: Array[RID] = []
	for node: Node3D in Enemies.all():
		var body := node as CollisionObject3D
		if body != null:
			rids.append(body.get_rid())
	return rids


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
	if _spot_stage == Spot.NONE:
		_spot = _investigate
		_spot_stage = Spot.GO
		_stuck = 0.0
	elif _investigate.distance_to(_spot) > SPOT_RETARGET:
		# A new sound or glimpse elsewhere: go there instead, and the check starts over.
		_spot = _investigate
		_spot_stage = Spot.GO
		_spot_timer = 0.0
		_stuck = 0.0
	if _spot_stage == Spot.GO:
		if _walk_to(_spot, _ai.investigate_speed, delta):
			_spot_stage = Spot.CHECK
			_spot_timer = 0.0
			_spot_yaw = _enemy.rotation.y
			_scan_clock = 0.0
		return
	# CHECK: stand at the spot and look around until the time is up (sensing something new restarts the time).
	if _since_sensed < 0.3:
		_spot_timer = 0.0
	_spot_timer += delta
	if _spot_timer >= _ai.spot_check_time:
		_end_spot()
		return
	_stop(delta)
	_scan_clock += delta
	var sweep := sin(_scan_clock * TAU / maxf(_ai.scan_period * 0.6, 0.1)) * deg_to_rad(_ai.spot_sweep_degrees)
	_turn_to_yaw(_spot_yaw + sweep, delta, _ai.look_turn_speed)


## The check is over: calm again, and back to the patrol (the nearest waypoint) or the post.
func _end_spot() -> void:
	_clear_spot()
	meter = _ai.suspicious_at * 0.6
	_since_sensed = 0.0
	_stuck = 0.0
	_resume_patrol()


func _clear_spot() -> void:
	_spot_stage = Spot.NONE
	_spot_timer = 0.0
	_spot_noises = 0


func _run_search(delta: float, target: Node3D) -> void:
	if _can_see and target != null:
		# It sees you but cannot reach you (another level): stay alert, stand and watch.
		_search_left = _search_cap()
		_stop(delta)
		_face_point(target.global_position + Vector3.UP * _ai.sight_target_height, delta)
		# Item 21: it throws something at you and calls for help (EnemyThrow), if this enemy is set up to.
		_enemy.throw_watch(delta, target)
		return
	if not _search_arrived:
		_search_arrived = _walk_to(_last_known, _ai.search_speed, delta)
		_search_yaw = _enemy.rotation.y
		if _search_arrived and _ai.search_roams:
			_roam_begin(Vector3(_last_known.x, _enemy.global_position.y, _last_known.z), _ai.search_roam_radius)
		return
	if _ai.search_roams:
		# Item 7e: one lap of points around the last known spot, then the search is over.
		if _roam_step(_ai.search_speed, delta):
			_end_search()
		return
	_stop(delta)
	_scan_clock += delta
	var sweep := sin(_scan_clock * TAU / maxf(_ai.scan_period * 0.6, 0.1)) * deg_to_rad(70.0)
	_turn_to_yaw(_search_yaw + sweep, delta, _ai.look_turn_speed)


## How long the alert search may last: one lap of the roam ends it itself, otherwise `search_time`.
func _search_cap() -> float:
	return 9999.0 if _ai.search_roams else _ai.search_time


func _end_search() -> void:
	_clear_spot()
	_search_left = 0.0
	meter = _ai.suspicious_at * 0.6
	_since_sensed = 0.0
	_stuck = 0.0
	_apply_level(Level.UNAWARE)
	_resume_patrol()


## Resume the patrol at the nearest waypoint (a post sends it home by itself).
func _resume_patrol() -> void:
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
	if distance <= ARRIVE_DISTANCE or not _enemy.can_reach_height(to.y):
		_stop(delta)
		_stuck = 0.0
		return true
	var direction := flat / distance
	if _enemy.use_navigation:
		# Item 12a: the next step of the navmesh path (zero: no path, it stands until the stuck timer gives up).
		direction = _enemy.nav_direction(point)
	var wanted := direction * speed
	if not edge_safe(direction):
		wanted = Vector3.ZERO
	_steer(wanted, delta)
	if direction != Vector3.ZERO:
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


## Like _walk_to, but it keeps facing `face_point` (a strafe around a body) and only reports true when it is
## stuck (it never "arrives"; the caller moves the point).
func _walk_facing(point: Vector3, speed: float, face_point: Vector3, delta: float) -> bool:
	var to := point - _enemy.global_position
	var flat := Vector3(to.x, 0.0, to.z)
	var distance := flat.length()
	if distance <= 0.15 or not _enemy.can_reach_height(to.y):
		_stop(delta)
		_face_point(face_point, delta)
		_stuck = 0.0
		return false
	var direction := flat / distance
	var wanted := direction * speed
	if not edge_safe(direction):
		wanted = Vector3.ZERO
	_steer(wanted, delta)
	_face_point(face_point, delta)
	var moving := Vector2(_enemy.velocity.x, _enemy.velocity.z).length()
	if moving < speed * 0.25:
		_stuck += delta
		if _stuck >= _ai.stuck_time:
			_stuck = 0.0
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
	_look_pitch = _pitch_to(point)
	_look_pitch_set = true
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
