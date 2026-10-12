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
	var probe := base - normal * (face_distance + 0.15)
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
	if ground.is_empty():
		return {}
	var ground_normal: Vector3 = ground["normal"]
	var ground_pos: Vector3 = ground["position"]
	if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
		return {}
	var stand_pos := Vector3(stand_xz.x, ground_pos.y, stand_xz.z)

	# 3. There must be room for the standing capsule up there.
	if not player.fits_standing_at(stand_pos + Vector3.UP * 0.02):
		return {}
	var hang_xz := base - normal * (face_distance - (radius + player.hang_gap))
	var hang_pos := Vector3(hang_xz.x, top_pos.y - player.hang_center_depth - player.stand_height * 0.5, hang_xz.z)
	var hang_spot := _find_hang_spot(hang_pos, normal, top_pos.y)
	if not hang_spot.is_empty():
		hang_pos = hang_spot["position"]
	return {
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
	player.last_ledge_ms = Time.get_ticks_msec()
	return true


## Which state a found ledge leads to: hang if interact is held (or was just pressed) and
## the hanging body fits there, otherwise the auto-climb.
func ledge_grab_state() -> StringName:
	var wants_hang := Input.is_action_pressed(Actions.INTERACT) or player.input_buffer.has_pressed(Actions.INTERACT)
	if wants_hang and player.ledge_hang_fits:
		player.input_buffer.consume(Actions.INTERACT)
		return StateName.LEDGE_HANG
	return StateName.LEDGE_CLIMB


## While hanging: finds the ledge top along the wall at the given feet position (near the
## last known ledge height). Returns {"top_y", "stand_position", "fits"} or {} if there is
## no ledge top there. "fits" says whether a standing body fits on top (needed to climb).
func probe_hang_ledge(pos: Vector3, normal: Vector3) -> Dictionary:
	var space := player.get_world_3d().direct_space_state
	var radius := player.get_body_radius()
	var face_distance := radius + player.hang_gap
	var base := Vector3(pos.x, 0.0, pos.z)
	var probe := base - normal * (face_distance + 0.15)
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
	return {
		"top_y": top_pos.y,
		"stand_position": stand_pos,
		"fits": player.fits_standing_at(stand_pos + Vector3.UP * 0.02),
	}


## True if the body fits with its feet at the given point (used while shimmying).
func can_hang_at(feet: Vector3) -> bool:
	return player.fits_standing_at(feet + Vector3.UP * 0.02)


## True if both hand points (either side of pos along the wall) find a flat ledge top
## near top_y just inside the wall face.
func _hands_on_ledge(pos: Vector3, normal: Vector3, top_y: float) -> bool:
	var space := player.get_world_3d().direct_space_state
	var radius := player.get_body_radius()
	var face_distance := radius + player.hang_gap
	var tangent := normal.cross(Vector3.UP).normalized()
	for side: float in [-1.0, 1.0]:
		var hand := Vector3(pos.x, 0.0, pos.z) + tangent * side * player.hang_hand_spacing
		var probe := hand - normal * (face_distance + 0.15)
		var query := PhysicsRayQueryParameters3D.create(
				Vector3(probe.x, top_y + 0.3, probe.z),
				Vector3(probe.x, top_y - 0.3, probe.z),
				_world_mask(), [player.get_rid()])
		var hit := space.intersect_ray(query)
		if hit.is_empty():
			return false
		var hit_normal: Vector3 = hit["normal"]
		if hit_normal.y < 0.9:
			return false
	return true


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
