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

@export_group("Input")
@export var input_buffer_time: float = 0.15

## Guard will set this later to force walking.
var walk_only: bool = false
## Set by actions during their i-frame window (read by the damage system in Step 4).
var invulnerable: bool = false
var coyote_timer: float = 0.0
var input_buffer: InputBuffer
var is_crouched: bool = false

var _headroom_shape: CapsuleShape3D
var _nose_drop: float = 0.4
var _visual_tween: Tween

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var state_machine: StateMachine = $StateMachine
@onready var _collision_shape: CollisionShape3D = $CollisionShape3D
@onready var _body_mesh: MeshInstance3D = $Visual/Body
@onready var _nose: MeshInstance3D = $Visual/Nose


func _ready() -> void:
	input_buffer = InputBuffer.new(input_buffer_time)
	_nose_drop = stand_height - _nose.position.y
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
	var params := PhysicsShapeQueryParameters3D.new()
	params.shape = _headroom_shape
	params.transform = Transform3D(Basis.IDENTITY, global_position + Vector3.UP * (0.07 + _headroom_shape.height * 0.5))
	params.collision_mask = collision_mask
	params.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(params, 1).is_empty()
