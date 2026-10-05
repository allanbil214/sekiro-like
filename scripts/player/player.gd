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

@export_group("Input")
@export var input_buffer_time: float = 0.15

## Guard will set this later to force walking.
var walk_only: bool = false
## Set by actions during their i-frame window (read by the damage system in Step 4).
var invulnerable: bool = false
var coyote_timer: float = 0.0
var input_buffer: InputBuffer

@onready var visual: Node3D = $Visual
@onready var camera_rig: Node3D = $CameraRig
@onready var state_machine: StateMachine = $StateMachine


func _ready() -> void:
	input_buffer = InputBuffer.new(input_buffer_time)
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


func apply_horizontal_movement(delta: float, speed: float) -> void:
	var move_dir := get_move_input()
	var target_vel := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else deceleration
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
