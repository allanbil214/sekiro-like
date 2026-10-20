class_name LedgeSensor
extends RefCounted
## Wall and ledge sensing for the Player (Step 12C): finds walls, ledges to grab, and hang spots
## with raycasts and shape queries. It owns no settings: the tuned exports (wall_range, ledge_*,
## hang_*) stay on the Player, and try_ledge_grab() stores the found ledge in the Player's
## ledge_* fields for the LedgeClimb and LedgeHang states.

var player: Player


func _init(owner_player: Player) -> void:
	player = owner_player


## The player's collision mask without the invisible walls (Layers.INVISIBLE_WALL): they block the
## body but are not a wall to wall-jump from or a ledge to grab.
func _world_mask() -> int:
	return player.collision_mask & ~Layers.INVISIBLE_WALL


## Nearest wall within wall_range of the capsule edge, from 8 horizontal rays at chest
## height. Returns {"normal": Vector3, "distance": float}, or {} if there is none.
func find_wall() -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var origin := player.global_position + Vector3.UP * (player.stand_height * 0.5)
	var reach := player.get_body_radius() + player.wall_range
	var best: Dictionary = {}
	var best_distance := INF
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, _world_mask(), [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			continue
		var normal: Vector3 = hit["normal"]
		if absf(normal.y) > 0.3:
			continue
		var distance := origin.distance_to(hit["position"])
		if distance < best_distance:
			best_distance = distance
			best = {
				"normal": Vector3(normal.x, 0.0, normal.z).normalized(),
				"distance": distance,
				"position": hit["position"],
			}
	return best


## Looks for a ledge to grab: airborne, near the top of a jump or falling, input toward a
## wall, a flat ledge top in the hand zone that is deep enough, and room to stand on it.
## Returns {"stand_position", "normal", "edge"} or {}.
func find_ledge() -> Dictionary:
	if player.is_on_floor() or player.velocity.y > player.ledge_max_rise_speed:
		return {}
	if Time.get_ticks_msec() < player.ledge_block_until_ms:
		return {}
	if player.ledge_requires_jump_held and not (Input.is_action_pressed(Actions.JUMP)
			or Input.is_action_pressed(Actions.INTERACT) or player.input_buffer.has_pressed(Actions.INTERACT)):
		return {}
	var want := player.get_move_input()
	want.y = 0.0
	if want.length_squared() < 0.01:
		return {}
	var wall := find_wall()
	if wall.is_empty():
		return {}
	var normal: Vector3 = wall["normal"]
	if want.normalized().dot(-normal) < player.ledge_input_threshold:
		return {}
	var hit_pos: Vector3 = wall["position"]
	var to_face := Vector3(hit_pos.x - player.global_position.x, 0.0, hit_pos.z - player.global_position.z)
	var face_distance := to_face.dot(-normal)
	var feet_y := player.global_position.y
	var space := player.get_world_3d().direct_space_state
	var radius := player.get_body_radius()
	var base := Vector3(player.global_position.x, 0.0, player.global_position.z)

	# 1. Ray down just inside the wall face to find the ledge top.
	var probe := base - normal * (face_distance + player.hang_min_depth)
	var top_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, feet_y + player.ledge_zone_max + 0.2, probe.z),
			Vector3(probe.x, feet_y + player.ledge_zone_min - 0.05, probe.z),
			_world_mask(), [player.get_rid()])
	var top := space.intersect_ray(top_query)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top["normal"]
	var top_pos: Vector3 = top["position"]
	if top_normal.y < 0.9 or top_pos.y < feet_y + player.ledge_zone_min or top_pos.y > feet_y + player.ledge_zone_max:
		return {}

	# 2. The top must be deep enough to stand on: check the landing spot.
	var stand_xz := base - normal * (face_distance + radius + player.ledge_standoff)
	var stand_query := PhysicsRayQueryParameters3D.create(
			Vector3(stand_xz.x, top_pos.y + 0.5, stand_xz.z),
			Vector3(stand_xz.x, top_pos.y - 0.3, stand_xz.z),
			_world_mask(), [player.get_rid()])
	var ground := space.intersect_ray(stand_query)
	# No standing spot on top (a thin wall or pillar): the ledge can only be hung from.
	var can_climb := not ground.is_empty()
	var stand_pos := Vector3.ZERO
	if can_climb:
		var ground_normal: Vector3 = ground["normal"]
		var ground_pos: Vector3 = ground["position"]
		if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
			can_climb = false
		else:
			stand_pos = Vector3(stand_xz.x, ground_pos.y, stand_xz.z)

	# 3. There must be room for the standing capsule up there; with room only to crouch the
	# climb is the low variant (item 13b). Not even that: the grab is refused.
	var low := false
	if can_climb and not player.fits_standing_at(stand_pos + Vector3.UP * 0.02):
		if not player.fits_crouching_at(stand_pos + Vector3.UP * 0.02):
			return {}
		low = true
	var hang_xz := base - normal * (face_distance - (radius + player.hang_gap))
	var hang_pos := Vector3(hang_xz.x, top_pos.y - player.hang_center_depth - player.stand_height * 0.5, hang_xz.z)
	var hang_spot := _find_hang_spot(hang_pos, normal, top_pos.y)
	if not hang_spot.is_empty():
		hang_pos = hang_spot["position"]
	if not can_climb and hang_spot.is_empty():
		return {}
	return {
		"can_climb": can_climb,
		"low": low,
		"stand_position": stand_pos,
		"normal": normal,
		"edge": top_pos,
		"top_y": top_pos.y,
		"hang_position": hang_pos,
		"hang_fits": not hang_spot.is_empty(),
	}


## If a ledge can be grabbed, stores it for the LedgeClimb state and returns true
## (the caller transitions to LedgeClimb).
func try_ledge_grab() -> bool:
	var ledge := find_ledge()
	if ledge.is_empty():
		return false
	player.ledge_stand_pos = ledge["stand_position"]
	player.ledge_wall_normal = ledge["normal"]
	player.last_ledge_point = ledge["edge"]
	player.ledge_top_y = ledge["top_y"]
	player.ledge_hang_pos = ledge["hang_position"]
	player.ledge_hang_fits = ledge["hang_fits"]
	player.ledge_can_climb = ledge["can_climb"]
	player.ledge_climb_low = ledge["low"]
	player.last_ledge_ms = Time.get_ticks_msec()
	return true


## Which state a found ledge leads to: hang if interact is held (or was just pressed) and
## the hanging body fits there, or always for a thin ledge that cannot be climbed; otherwise
## the auto-climb.
func ledge_grab_state() -> StringName:
	var wants_hang := Input.is_action_pressed(Actions.INTERACT) or player.input_buffer.has_pressed(Actions.INTERACT)
	if player.ledge_hang_fits and (wants_hang or not player.ledge_can_climb):
		player.input_buffer.consume(Actions.INTERACT)
		return StateName.LEDGE_HANG
	return StateName.LEDGE_CLIMB


## While hanging: finds the ledge top along the wall at the given feet position (near the
## last known ledge height). Returns {"top_y", "stand_position", "fits", "low"} or {} if there is
## no ledge top there. "fits" says whether a body fits on top (needed to climb); "low" is true
## when only a crouching body fits (the low climb, item 13b).
func probe_hang_ledge(pos: Vector3, normal: Vector3) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var radius := player.get_body_radius()
	var face_distance := radius + player.hang_gap
	var base := Vector3(pos.x, 0.0, pos.z)
	var probe := base - normal * (face_distance + player.hang_min_depth)
	var top_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, player.ledge_top_y + 0.3, probe.z),
			Vector3(probe.x, player.ledge_top_y - 0.3, probe.z),
			_world_mask(), [player.get_rid()])
	var top := space.intersect_ray(top_query)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top["normal"]
	if top_normal.y < 0.9:
		return {}
	var top_pos: Vector3 = top["position"]
	if not _hands_on_ledge(pos, normal, player.ledge_top_y):
		return {}
	var stand_xz := base - normal * (face_distance + radius + player.ledge_standoff)
	var ground_query := PhysicsRayQueryParameters3D.create(
			Vector3(stand_xz.x, top_pos.y + 0.5, stand_xz.z),
			Vector3(stand_xz.x, top_pos.y - 0.3, stand_xz.z),
			_world_mask(), [player.get_rid()])
	var ground := space.intersect_ray(ground_query)
	if ground.is_empty():
		return {"top_y": top_pos.y, "fits": false}
	var ground_normal: Vector3 = ground["normal"]
	var ground_pos: Vector3 = ground["position"]
	if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
		return {"top_y": top_pos.y, "fits": false}
	var stand_pos := Vector3(stand_xz.x, ground_pos.y, stand_xz.z)
	var feet := stand_pos + Vector3.UP * 0.02
	var fits_standing := player.fits_standing_at(feet)
	return {
		"top_y": top_pos.y,
		"stand_position": stand_pos,
		"fits": fits_standing or player.fits_crouching_at(feet),
		"low": not fits_standing,
	}


## While hanging at the end of the ledge, looks for a square (90 degree) corner in the shimmy
## direction `dir` (unit, along the wall): an inside corner (a wall ahead, the ledge turns toward
## you) or an outside corner (the wall ends and its side face continues the ledge). Returns
## {"position", "control", "normal", "top_y", "outside"} for the hang spot on the new wall, or {}.
## "control" is the middle point of the curved path the turn follows.
func find_corner(pos: Vector3, normal: Vector3, dir: Vector3) -> Dictionary:
	var inside := _find_inside_corner(pos, normal, dir)
	if not inside.is_empty():
		return inside
	return _find_outside_corner(pos, normal, dir)


func _find_inside_corner(pos: Vector3, normal: Vector3, dir: Vector3) -> Dictionary:
	var face_distance := player.get_body_radius() + player.hang_gap
	var origin := Vector3(pos.x, player.ledge_top_y - 0.4, pos.z)
	var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * (face_distance + player.corner_reach),
			_world_mask(), [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_normal: Vector3 = hit["normal"]
	if absf(hit_normal.y) > 0.3:
		return {}
	var flat := Vector3(hit_normal.x, 0.0, hit_normal.z).normalized()
	if flat.dot(-dir) < 0.9:
		return {}
	var hit_pos: Vector3 = hit["position"]
	var along := (hit_pos - pos).dot(dir)
	var base := pos + dir * (along - face_distance)
	# Slide away from the first wall until both hands are on the new ledge.
	for i in 9:
		var candidate := base + normal * 0.05 * float(i)
		var probe := _probe_corner_spot(candidate, -dir)
		if not probe.is_empty():
			return {
				"position": candidate,
				"control": (pos + candidate) * 0.5,
				"normal": -dir,
				"top_y": probe["top_y"],
				"outside": false,
			}
	return {}


func _find_outside_corner(pos: Vector3, normal: Vector3, dir: Vector3) -> Dictionary:
	var face_distance := player.get_body_radius() + player.hang_gap
	# A ray back toward the hang spot from beyond the corner, just inside the first wall face,
	# finds the side face of the block (its normal must point along dir).
	var start_along := player.hang_hand_spacing + player.corner_reach
	var origin := Vector3(pos.x, player.ledge_top_y - 0.4, pos.z) + dir * start_along - normal * (face_distance + player.hang_min_depth)
	var query := PhysicsRayQueryParameters3D.create(origin, origin - dir * (start_along + 0.2),
			_world_mask(), [player.get_rid()])
	var hit := player.get_world_3d().direct_space_state.intersect_ray(query)
	if hit.is_empty():
		return {}
	var hit_normal: Vector3 = hit["normal"]
	if absf(hit_normal.y) > 0.3:
		return {}
	var flat := Vector3(hit_normal.x, 0.0, hit_normal.z).normalized()
	if flat.dot(dir) < 0.9:
		return {}
	var hit_pos: Vector3 = hit["position"]
	var along := (hit_pos - pos).dot(dir)
	var out_point := pos + dir * (along + face_distance)
	var control := pos + dir * (along + face_distance * 1.3) + normal * (face_distance * 0.3)
	# Step onto the new face far enough that both hands are on the ledge.
	# Full hand spacing first, then deeper onto the face, then closer to the corner for a thin face.
	var offsets: Array[float] = []
	for i in 7:
		offsets.append(player.hang_hand_spacing + 0.05 * float(i))
	var narrow := player.hang_hand_spacing - 0.05
	while narrow >= player.hang_min_width * 0.5 - 0.001:
		offsets.append(narrow)
		narrow -= 0.05
	for offset: float in offsets:
		var candidate := out_point - normal * (face_distance + offset)
		var probe := _probe_corner_spot(candidate, dir)
		if not probe.is_empty():
			return {
				"position": candidate,
				"control": control,
				"normal": dir,
				"top_y": probe["top_y"],
				"outside": true,
			}
	return {}


## A hang spot after a corner turn is good if both hands are on the new ledge and the body fits
## (the same test the shimmy uses). Returns the probe result or {}.
func _probe_corner_spot(candidate: Vector3, new_normal: Vector3) -> Dictionary:
	var probe := probe_hang_ledge(candidate, new_normal)
	if probe.is_empty() or not can_hang_at(candidate):
		return {}
	return probe


## True if the body fits with its feet at the given point (used while shimmying).
func can_hang_at(feet: Vector3) -> bool:
	return player.fits_standing_at(feet + Vector3.UP * 0.02)


## True if both hands find a flat ledge top near top_y just inside the wall face. The hands sit
## hang_hand_spacing either side of pos, or closer on a narrow ledge (never closer than half of
## hang_min_width). The spacing in use is stored in player.ledge_hand_spacing.
func _hands_on_ledge(pos: Vector3, normal: Vector3, top_y: float) -> bool:
	var spacing := minf(_ledge_extent(pos, normal, top_y, -1.0), _ledge_extent(pos, normal, top_y, 1.0))
	var min_spacing := minf(player.hang_min_width * 0.5, player.hang_hand_spacing)
	if spacing < min_spacing - 0.001:
		return false
	player.ledge_hand_spacing = spacing
	return true


## How far (m, up to hang_hand_spacing) the ledge top continues from pos along the wall on one
## side (-1 or 1), sampled every 0.05 m; 0 if there is no ledge top at pos itself.
func _ledge_extent(pos: Vector3, normal: Vector3, top_y: float, side: float) -> float:
	var space := player.get_world_3d().direct_space_state
	var face_distance := player.get_body_radius() + player.hang_gap
	var tangent := normal.cross(Vector3.UP).normalized()
	var extent := 0.0
	var steps := int(round(player.hang_hand_spacing / 0.05))
	for i in range(steps + 1):
		var hand := Vector3(pos.x, 0.0, pos.z) + tangent * side * 0.05 * float(i)
		var probe := hand - normal * (face_distance + player.hang_min_depth)
		var query := PhysicsRayQueryParameters3D.create(
				Vector3(probe.x, top_y + 0.3, probe.z),
				Vector3(probe.x, top_y - 0.3, probe.z),
				_world_mask(), [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			break
		var hit_normal: Vector3 = hit["normal"]
		if hit_normal.y < 0.9:
			break
		extent = 0.05 * float(i)
	return extent


## Finds the hang position closest to the wanted one (shifting sideways along the wall, up
## to hang_adjust_max) where both hands are on the ledge and the body fits.
## Returns {"position": Vector3} or {} if there is none.
func _find_hang_spot(wanted: Vector3, normal: Vector3, top_y: float) -> Dictionary:
	var tangent := normal.cross(Vector3.UP).normalized()
	var step := 0.05
	var count := int(ceil(player.hang_adjust_max / step))
	for i in range(count + 1):
		for side: float in [1.0, -1.0]:
			if i == 0 and side < 0.0:
				continue
			var candidate := wanted + tangent * side * step * float(i)
			if _hands_on_ledge(candidate, normal, top_y) and player.fits_standing_at(candidate + Vector3.UP * 0.02):
				return {"position": candidate}
	return {}
