extends CharacterBody3D
## Step 1: basic movement + jump. Will be restructured into states in step 2.

@export_group("Movement")
@export var run_speed: float = 6.5
@export var walk_speed: float = 2.5
@export var acceleration: float = 50.0
@export var deceleration: float = 60.0
@export var turn_speed: float = 18.0

@export_group("Jump")
@export var jump_velocity: float = 7.0
@export var gravity_multiplier: float = 2.0
@export var coyote_time: float = 0.1
@export var jump_buffer_time: float = 0.15

## Guard will set this later to force walking.
var walk_only: bool = false

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0

@onready var _visual: Node3D = $Visual
@onready var _camera_rig: Node3D = $CameraRig


func _physics_process(delta: float) -> void:
	_apply_gravity_and_jump(delta)
	_apply_movement(delta)
	move_and_slide()


func _apply_gravity_and_jump(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)
		velocity += get_gravity() * gravity_multiplier * delta

	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0


func _apply_movement(delta: float) -> void:
	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var cam_basis := Basis(Vector3.UP, _camera_rig.global_rotation.y)
	var move_dir: Vector3 = cam_basis * Vector3(input_dir.x, 0.0, input_dir.y)

	var speed := walk_speed if walk_only else run_speed
	var target_vel := move_dir * speed
	var horizontal := Vector3(velocity.x, 0.0, velocity.z)
	var rate := acceleration if move_dir.length_squared() > 0.0 else deceleration
	horizontal = horizontal.move_toward(target_vel, rate * delta)
	velocity.x = horizontal.x
	velocity.z = horizontal.z

	if move_dir.length_squared() > 0.01:
		var target_yaw := atan2(-move_dir.x, -move_dir.z)
		_visual.rotation.y = lerp_angle(
				_visual.rotation.y, target_yaw, 1.0 - exp(-turn_speed * delta))
