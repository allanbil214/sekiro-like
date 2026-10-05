class_name Player
extends CharacterBody3D
## Shared player data and helpers. Behavior lives in the states under StateMachine.

@export_group("Movement")
@export var run_speed: float = 6.5
@export var walk_speed: float = 2.5
@export var dash_speed: float = 9.0
@export var acceleration: float = 50.0
@export var deceleration: float = 60.0
@export var turn_speed: float = 18.0

@export_group("Jump")
@export var jump_velocity: float = 7.0
@export var gravity_multiplier: float = 2.0
@export var coyote_time: float = 0.1

@export_group("Crouch")
## Placeholder speed while crouched (m/s).
@export var crouch_speed: float = 2.0
## How fast you slow down to crouch_speed when entering crouch faster than that (m/s^2).
@export var crouch_decel: float = 12.0
## Seconds the mesh takes to ease between standing and crouched height (collision is instant).
@export var crouch_transition_time: float = 0.12
## Capsule height while standing and crouched. Crouch shrinks from the top; feet stay planted.
@export var stand_height: float = 1.8
@export var crouch_height: float = 1.1
## Off = press to toggle crouch. On = crouch only while the button is held.
@export var crouch_is_hold: bool = false

@export_group("Reach and wall jump")
## Wall jump speed multiplier: up = jump_velocity * boost, sideways/back = run_speed * boost.
@export var wall_jump_boost: float = 1.2
## A wall counts if it is within this distance (m) of the capsule edge, at chest height.
@export var wall_range: float = 0.6
@export var max_wall_jumps: int = 2
## How directly the input must point toward/away from the wall (dot product, 0.5 = within 60 degrees).
@export var wall_input_threshold: float = 0.75
## Air jump presses this close to the floor (m) are left buffered for the landing jump.
@export var air_jump_ground_margin: float = 0.3

@export_group("Ledge")
## Hand zone: a ledge top counts if it is between these heights above the feet (m).
@export var ledge_zone_min: float = 1.4
@export var ledge_zone_max: float = 2.1
## How directly the input must point at the wall to grab a ledge (dot product, 0.5 = within 60 degrees).
@export var ledge_input_threshold: float = 0.5
## No ledge grab while rising faster than this (m/s). 99 = no limit (grab while rising too).
@export var ledge_max_rise_speed: float = 99.0
## Only grab a ledge while the jump button is held (stops accidental re-grabs after a drop).
@export var ledge_requires_jump_held: bool = true
## Gap (m) between the capsule and the wall edge at the landing spot on top.
@export var ledge_standoff: float = 0.1

@export_group("Input")
@export var input_buffer_time: float = 0.15

## Guard will set this later to force walking.
var walk_only: bool = false
## Set by actions during their i-frame window (read by the damage system in Step 4).
var invulnerable: bool = false
var coyote_timer: float = 0.0
var input_buffer: InputBuffer
var is_crouched: bool = false
## Mid-air reach is once per airtime; a wall jump restores it. Landing resets both.
var reach_ready: bool = true
var wall_jumps_used: int = 0
## Set by try_air_jump() when it returns true: the surface normal of the wall to jump from.
var wall_normal: Vector3 = Vector3.ZERO
## Set by try_ledge_grab() when it returns true (read by the LedgeClimb state).
var ledge_stand_pos: Vector3 = Vector3.ZERO
var ledge_wall_normal: Vector3 = Vector3.ZERO
## Debug: where the last ledge was found, and when (msec).
var last_ledge_point: Vector3 = Vector3.ZERO
var last_ledge_ms: int = -100000

var _headroom_shape: CapsuleShape3D
var _nose_drop: float = 0.4
var _visual_tween: Tween
var _reach_arms: ReachArms

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var state_machine: StateMachine = $StateMachine
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose


func _ready() -> void:
	input_buffer = InputBuffer.new(input_buffer_time)
	_nose_drop = stand_height - _nose.position.y
	_reach_arms = get_node_or_null("Visual/ReachArms") as ReachArms
	_headroom_shape = CapsuleShape3D.new()
	_headroom_shape.radius = 0.38
	_headroom_shape.height = stand_height - 0.07
	state_machine.setup(self)
	state_machine.start()


func _physics_process(delta: float) -> void:
	input_buffer.tick(delta)
	state_machine.physics_update(delta)
	move_and_slide()


## Movement input in world space, relative to the camera. Length 0 to 1.
func get_move_input() -> Vector3:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, camera_rig.global_rotation.y)
	return cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)


func get_move_speed() -> float:
	return walk_speed if walk_only else run_speed


func get_facing_direction() -> Vector3:
	return -visual.global_transform.basis.z


func apply_gravity(delta: float) -> void:
	velocity += get_gravity() * gravity_multiplier * delta


func start_jump() -> void:
	velocity.y = jump_velocity
	coyote_timer = 0.0


## If overspeed_decel > 0 and there is input while faster than speed, slow down at that rate.
func apply_horizontal_movement(delta: float, speed: float, overspeed_decel: float = -1.0) -> void:
	var move_dir := get_move_input()
	var target_vel := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else deceleration
	if overspeed_decel > 0.0 and move_dir.length_squared() > 0.0 and horizontal.length() > speed:
		rate = overspeed_decel
	horizontal = horizontal.move_toward(target_vel, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func decelerate(delta: float) -> void:
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	horizontal = horizontal.move_toward(Vector3.ZERO, deceleration * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z


func set_horizontal_velocity(v: Vector3) -> void:
	velocity.x = v.x
	velocity.z = v.z


## Turn smoothly toward the movement input (if any).
func face_input(delta: float) -> void:
	var move_dir := get_move_input()
	if move_dir.length_squared() > 0.01:
		face_direction(move_dir, delta)


func face_direction(dir: Vector3, delta: float) -> void:
	var target_yaw := atan2(-dir.x, -dir.z)
	visual.rotation.y = lerp_angle(visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))


## Turn instantly (used when an action starts).
func snap_facing(dir: Vector3) -> void:
	visual.rotation.y = atan2(-dir.x, -dir.z)


## Resize the body. The collision capsule changes instantly (sizes are set on the shape
## resource, never by scaling the node); the mesh and nose ease over crouch_transition_time.
## The bottom stays at the feet.
func set_crouched(crouched: bool) -> void:
	is_crouched = crouched
	var height := crouch_height if crouched else stand_height
	var shape := _collision_shape.shape as CapsuleShape3D
	shape.height = height
	_collision_shape.position.y = height * 0.5
	var mesh := _body_mesh.mesh as CapsuleMesh
	var nose_y := height - _nose_drop
	if _visual_tween != null:
		_visual_tween.kill()
	if crouch_transition_time <= 0.0:
		mesh.height = height
		_body_mesh.position.y = height * 0.5
		_nose.position.y = nose_y
		return
	_visual_tween = create_tween().set_parallel(true).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	_visual_tween.tween_property(mesh, "height", height, crouch_transition_time)
	_visual_tween.tween_property(_body_mesh, "position:y", height * 0.5, crouch_transition_time)
	_visual_tween.tween_property(_nose, "position:y", nose_y, crouch_transition_time)


## True if there is room above to stand up (checked with a standing-sized capsule).
func can_stand() -> bool:
	return _fits_standing_at(global_position)


## True if a standing capsule fits with its feet at the given point.
func _fits_standing_at(feet: Vector3) -> bool:
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, feet + Vector3.UP * (0.07 + _headroom_shape.height * 0.5))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()


func reset_air_actions() -> void:
	reach_ready = true
	wall_jumps_used = 0


func play_reach_arms() -> void:
	if _reach_arms != null:
		_reach_arms.play()


## Slide pose: arms held straight forward at crouched shoulder height until stop_slide_arms().
func play_climb_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_up()


func release_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


func play_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.hold_forward(crouch_height - _nose_drop)


func stop_slide_arms() -> void:
	if _reach_arms != null:
		_reach_arms.release()


## True if the floor is within air_jump_ground_margin below the feet.
func is_near_ground() -> bool:
	var from := global_position + Vector3.UP * 0.05
	var to := global_position + Vector3.DOWN * air_jump_ground_margin
	var query := PhysicsRayQueryParameters3D.create(from, to, collision_mask, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(query).is_empty()


## Nearest wall within wall_range of the capsule edge, from 8 horizontal rays at chest
## height. Returns {"normal": Vector3, "distance": float}, or {} if there is none.
func find_wall() -> Dictionary:
	var space := get_world_3d().direct_space_state
	var capsule := _collision_shape.shape as CapsuleShape3D
	var origin := global_position + Vector3.UP * (stand_height * 0.5)
	var reach := capsule.radius + wall_range
	var best: Dictionary = {}
	var best_distance := INF
	for i in 8:
		var angle := TAU * float(i) / 8.0
		var dir := Vector3(sin(angle), 0.0, cos(angle))
		var query := PhysicsRayQueryParameters3D.create(origin, origin + dir * reach, collision_mask, [get_rid()])
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


## Handles a jump press made in mid-air (after the coyote jump had its chance).
## Returns true if a wall jump should start (wall_normal is set; the caller transitions
## to WallJump). Otherwise it may play the reach, and returns false.
func try_air_jump() -> bool:
	if not input_buffer.has_pressed(&"jump") or is_near_ground():
		return false
	input_buffer.consume(&"jump")
	if wall_jumps_used < max_wall_jumps:
		var wall := find_wall()
		if not wall.is_empty():
			wall_normal = wall["normal"]
			return true
	if reach_ready:
		reach_ready = false
		play_reach_arms()
	return false


## Looks for a ledge to grab: airborne, near the top of a jump or falling, input toward a
## wall, a flat ledge top in the hand zone that is deep enough, and room to stand on it.
## Returns {"stand_position", "normal", "edge"} or {}.
func find_ledge() -> Dictionary:
	if is_on_floor() or velocity.y > ledge_max_rise_speed:
		return {}
	if ledge_requires_jump_held and not Input.is_action_pressed("jump"):
		return {}
	var want := get_move_input()
	want.y = 0.0
	if want.length_squared() < 0.01:
		return {}
	var wall := find_wall()
	if wall.is_empty():
		return {}
	var normal: Vector3 = wall["normal"]
	if want.normalized().dot(-normal) < ledge_input_threshold:
		return {}
	var hit_pos: Vector3 = wall["position"]
	var to_face := Vector3(hit_pos.x - global_position.x, 0.0, hit_pos.z - global_position.z)
	var face_distance := to_face.dot(-normal)
	var feet_y := global_position.y
	var space := get_world_3d().direct_space_state
	var radius := (_collision_shape.shape as CapsuleShape3D).radius
	var base := Vector3(global_position.x, 0.0, global_position.z)

	# 1. Ray down just inside the wall face to find the ledge top.
	var probe := base - normal * (face_distance + 0.15)
	var top_query := PhysicsRayQueryParameters3D.create(
			Vector3(probe.x, feet_y + ledge_zone_max + 0.2, probe.z),
			Vector3(probe.x, feet_y + ledge_zone_min - 0.05, probe.z),
			collision_mask, [get_rid()])
	var top := space.intersect_ray(top_query)
	if top.is_empty():
		return {}
	var top_normal: Vector3 = top["normal"]
	var top_pos: Vector3 = top["position"]
	if top_normal.y < 0.9 or top_pos.y < feet_y + ledge_zone_min or top_pos.y > feet_y + ledge_zone_max:
		return {}

	# 2. The top must be deep enough to stand on: check the landing spot.
	var stand_xz := base - normal * (face_distance + radius + ledge_standoff)
	var stand_query := PhysicsRayQueryParameters3D.create(
			Vector3(stand_xz.x, top_pos.y + 0.5, stand_xz.z),
			Vector3(stand_xz.x, top_pos.y - 0.3, stand_xz.z),
			collision_mask, [get_rid()])
	var ground := space.intersect_ray(stand_query)
	if ground.is_empty():
		return {}
	var ground_normal: Vector3 = ground["normal"]
	var ground_pos: Vector3 = ground["position"]
	if ground_normal.y < 0.9 or absf(ground_pos.y - top_pos.y) > 0.1:
		return {}
	var stand_pos := Vector3(stand_xz.x, ground_pos.y, stand_xz.z)

	# 3. There must be room for the standing capsule up there.
	if not _fits_standing_at(stand_pos + Vector3.UP * 0.02):
		return {}
	return {"stand_position": stand_pos, "normal": normal, "edge": top_pos}


## If a ledge can be grabbed, stores it for the LedgeClimb state and returns true
## (the caller transitions to LedgeClimb).
func try_ledge_grab() -> bool:
	var ledge := find_ledge()
	if ledge.is_empty():
		return false
	ledge_stand_pos = ledge["stand_position"]
	ledge_wall_normal = ledge["normal"]
	last_ledge_point = ledge["edge"]
	last_ledge_ms = Time.get_ticks_msec()
	return true


## Turn the body collision on or off (used during the scripted ledge climb).
func set_body_collision_enabled(enabled: bool) -> void:
	_collision_shape.set_deferred("disabled", not enabled)