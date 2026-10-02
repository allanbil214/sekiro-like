extends Node3D
## Third-person orbit camera. Follows its parent (the player) without inheriting its rotation.

@export var target: Node3D
@export var follow_height: float = 1.5
@export var follow_smoothing: float = 20.0
@export var mouse_sensitivity: float = 0.0025
@export var stick_sensitivity: float = 3.0
@export var pitch_min_deg: float = -60.0
@export var pitch_max_deg: float = 30.0

var _yaw: float = 0.0
var _pitch: float = -0.2

@onready var _arm: SpringArm3D = $SpringArm3D


func _ready() -> void:
	top_level = true
	if target == null:
		target = get_parent() as Node3D
	var body := target as CollisionObject3D
	if body != null:
		_arm.add_excluded_object(body.get_rid())
	global_position = target.global_position + Vector3.UP * follow_height
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _unhandled_input(event: InputEvent) -> void:
	var motion := event as InputEventMouseMotion
	var click := event as InputEventMouseButton
	if motion != null and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= motion.relative.x * mouse_sensitivity
		_pitch -= motion.relative.y * mouse_sensitivity
	elif event.is_action_pressed("ui_cancel"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif click != null and click.pressed and Input.mouse_mode == Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _process(delta: float) -> void:
	var look := Input.get_vector("look_left", "look_right", "look_up", "look_down")
	_yaw -= look.x * stick_sensitivity * delta
	_pitch -= look.y * stick_sensitivity * delta
	_pitch = clampf(_pitch, deg_to_rad(pitch_min_deg), deg_to_rad(pitch_max_deg))

	rotation.y = _yaw
	_arm.rotation.x = _pitch

	var goal := target.global_position + Vector3.UP * follow_height
	global_position = global_position.lerp(goal, 1.0 - exp(-follow_smoothing * delta))
