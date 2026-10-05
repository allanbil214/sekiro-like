class_name ReachArms
extends Node3D
## Debug stand-in for the mid-air reach animation: two arms snap up and forward, hold
## briefly, then drop. Builds its own boxes. Place under Visual so it turns with the body.

@export var shoulder_height: float = 1.4
@export var shoulder_offset: float = 0.45
@export var arm_length: float = 0.5
@export var raise_time: float = 0.08
@export var hold_time: float = 0.15
@export var lower_time: float = 0.12
@export var raised_angle_deg: float = 140.0
## Pose angle while sliding: 90 = arms straight forward.
@export var slide_angle_deg: float = 90.0
## Pose angle while climbing a ledge: 180 = arms straight up.
@export var climb_angle_deg: float = 180.0
@export var color: Color = Color(1.0, 0.6, 0.15)

var _pivots: Array[Node3D] = []
var _tween: Tween
var _angle_deg: float = 140.0
var _amount: float = 0.0


func _ready() -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	for side in [-1.0, 1.0]:
		var pivot := Node3D.new()
		pivot.position = Vector3(side * shoulder_offset, shoulder_height, 0.0)
		var box := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(0.1, arm_length, 0.1)
		box.mesh = mesh
		box.material_override = material
		box.position = Vector3(0.0, -arm_length * 0.5, 0.0)
		pivot.add_child(box)
		add_child(pivot)
		_pivots.append(pivot)
	visible = false


func play() -> void:
	if _tween != null:
		_tween.kill()
	_angle_deg = raised_angle_deg
	_set_shoulder_height(shoulder_height)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_pose, 0.0, 1.0, raise_time)
	_tween.tween_interval(hold_time)
	_tween.tween_method(_set_pose, 1.0, 0.0, lower_time)
	_tween.tween_callback(func() -> void: visible = false)


## Swing the arms forward (slide_angle_deg) and keep them there until release().
func hold_forward(shoulder_y: float) -> void:
	_hold(slide_angle_deg, shoulder_y)


## Swing the arms straight up (climb_angle_deg) and keep them there until release().
func hold_up() -> void:
	_hold(climb_angle_deg, shoulder_height)


func _hold(angle_deg: float, shoulder_y: float) -> void:
	if _tween != null:
		_tween.kill()
	_angle_deg = angle_deg
	_set_shoulder_height(shoulder_y)
	visible = true
	_tween = create_tween()
	_tween.tween_method(_set_pose, _amount, 1.0, raise_time)


## Lower the arms and hide them.
func release() -> void:
	if not visible:
		return
	if _tween != null:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_method(_set_pose, _amount, 0.0, lower_time)
	_tween.tween_callback(func() -> void: visible = false)


func _set_shoulder_height(y: float) -> void:
	for pivot in _pivots:
		pivot.position.y = y


func _set_pose(amount: float) -> void:
	_amount = amount
	for pivot in _pivots:
		pivot.rotation.x = deg_to_rad(_angle_deg) * amount
