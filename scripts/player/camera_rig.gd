class_name CameraRig
extends Node3D
## Third-person orbit camera. Follows its parent (the player) without inheriting its rotation.
## Lock-on (Step 9): while the sibling LockOn node has a target, the camera eases toward it (yaw and
## pitch) from a little higher up, and the mouse and the right stick no longer look around (the mouse
## movement is passed to LockOn as a switch flick instead). On release, free look continues from
## where the camera is.

@export var target: Node3D
@export var follow_height: float = 1.5
@export var follow_smoothing: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 3.0
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 30.0
@export_group("Lock-on (Step 9)")
## Extra camera height (m) while locked on.
@export var lock_height_bonus: float = 0.8
## Extra downward tilt (degrees) while locked on, on top of aiming at the target, so less sky shows.
@export var lock_pitch_down_degrees: float = 10.0
## How fast the camera eases toward the target and the extra height (higher = snappier).
@export var lock_follow_speed: float = 8.0
## How fast a recenter turns the camera behind the player (LockOn.recenter_when_no_target).
@export var recenter_speed: float = 10.0

var _yaw: float = 0.0
var _pitch: float = -0.2
var _height_now: float = 0.0
var _recentering: bool = false
var _recenter_yaw: float = 0.0

@onready var _arm: SpringArm3D = $SpringArm3D
@onready var _lock_on: LockOn = $"../LockOn"


func _ready() -> void:
	top_level = true
	if target == null:
		target = get_parent() as Node3D
	var body := target as CollisionObject3D
	if body != null:
		_arm.add_excluded_object(body.get_rid())
	_height_now = follow_height
	global_position = target.global_position + Vector3.UP * follow_height
	_lock_on.recenter_requested.connect(_on_recenter_requested)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var click := event as InputEventMouseButton
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if _lock_on.has_target():
			_lock_on.feed_flick(motion.relative.x)
		else:
			_recentering = false
			_yaw -= motion.relative.x * mouse_sensitivity
			_pitch -= motion.relative.y * mouse_sensitivity
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif click != null and click.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var locked := _lock_on.has_target()
	if locked:
		_recentering = false
		_aim_at_lock_target(delta)
	else:
		var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
		_yaw -= look.x * stick_sensitivity * delta
		_pitch -= look.y * stick_sensitivity * delta
		if _recentering:
			_yaw = lerp_angle(_yaw, _recenter_yaw, 1.0 - exp(-recenter_speed * delta))
			if absf(angle_difference(_yaw, _recenter_yaw)) < 0.01:
				_recentering = false
	_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

	rotation.y = _yaw
	_arm.rotation.x = _pitch

	var wanted_height := follow_height + (lock_height_bonus if locked else 0.0)
	_height_now = lerpf(_height_now, wanted_height, 1.0 - exp(-lock_follow_speed * delta))
	var goal := target.global_position + Vector3.UP * _height_now
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))


## Ease yaw and pitch so the camera looks along the line from its pivot to the target.
func _aim_at_lock_target(delta: float) -> void:
	var to := _lock_on.get_target_position() - global_position
	var flat := Vector2(to.x, to.z).length()
	if flat < 0.2:
		return
	var weight := 1.0 - exp(-lock_follow_speed * delta)
	_yaw = lerp_angle(_yaw, atan2(-to.x, -to.z), weight)
	_pitch = lerpf(_pitch, atan2(to.y, flat) - deg_to_rad(lock_pitch_down_degrees), weight)


func _on_recenter_requested(yaw: float) -> void:
	_recenter_yaw = yaw
	_recentering = true
